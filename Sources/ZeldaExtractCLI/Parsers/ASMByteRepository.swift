import Foundation

struct ASMByteBlock: Sendable {
    let label: String
    let fileURL: URL
    let bytes: [UInt8]
}

struct ASMByteRepository {
    private static let supportedExtensions = Set(["asm", "inc", "s"])

    func load(from sourceURL: URL?) -> [ASMByteBlock] {
        guard let sourceURL, FileManager.default.fileExists(atPath: sourceURL.path()) else {
            return []
        }

        let files = asmFiles(in: sourceURL)
        var blocks: [ASMByteBlock] = []
        for fileURL in files {
            blocks.append(contentsOf: parseBlocks(in: fileURL))
        }
        return blocks
    }

    private func asmFiles(in sourceURL: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            guard Self.supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
            files.append(fileURL)
        }

        return files.sorted { $0.path() < $1.path() }
    }

    private func parseBlocks(in fileURL: URL) -> [ASMByteBlock] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }

        let lines = content.split(whereSeparator: \.isNewline).map(String.init)
        var blocks: [ASMByteBlock] = []
        var currentLabel: String?
        var currentBytes: [UInt8] = []
        var anonymousCounter = 0

        func flush() {
            guard let label = currentLabel, !currentBytes.isEmpty else { return }
            blocks.append(ASMByteBlock(label: label, fileURL: fileURL, bytes: currentBytes))
            currentLabel = nil
            currentBytes = []
        }

        for line in lines {
            let stripped = stripComment(from: line).trimmingCharacters(in: .whitespaces)
            guard !stripped.isEmpty else { continue }

            if let (label, remainder) = parseLabelLine(stripped) {
                flush()
                currentLabel = label

                if let bytes = parseDirectiveBytes(from: remainder, relativeTo: fileURL), !bytes.isEmpty {
                    currentBytes.append(contentsOf: bytes)
                }

                continue
            }

            if let bytes = parseDirectiveBytes(from: stripped, relativeTo: fileURL), !bytes.isEmpty {
                if currentLabel == nil {
                    anonymousCounter += 1
                    currentLabel = "__anonymous_\(anonymousCounter)"
                }
                currentBytes.append(contentsOf: bytes)
            }
        }

        flush()
        return blocks
    }

    private func stripComment(from line: String) -> String {
        guard let commentIndex = line.firstIndex(of: ";") else { return line }
        return String(line[..<commentIndex])
    }

    private func parseLabelLine(_ line: String) -> (String, String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }

        let left = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
        let right = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)

        guard !left.isEmpty else { return nil }
        guard left.range(of: #"^[A-Za-z_\.][A-Za-z0-9_\.]*$"#, options: .regularExpression) != nil else {
            return nil
        }

        return (left, right)
    }

    private func parseDirectiveBytes(from line: String, relativeTo fileURL: URL) -> [UInt8]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()

        let directive: String
        if lowered.hasPrefix(".byte") {
            directive = ".byte"
        } else if lowered.hasPrefix(".db") {
            directive = ".db"
        } else if lowered.hasPrefix(".incbin") {
            directive = ".incbin"
        } else {
            return nil
        }

        let payload = String(trimmed.dropFirst(directive.count)).trimmingCharacters(in: .whitespaces)
        guard !payload.isEmpty else { return [] }

        if directive == ".incbin" {
            return parseIncbinBytes(payload, relativeTo: fileURL)
        }

        let values = splitCSV(payload).flatMap { parseTokenBytes($0) }

        return values
    }

    private func splitCSV(_ payload: String) -> [String] {
        var tokens: [String] = []
        var buffer = ""
        var inQuotes = false

        for character in payload {
            if character == "\"" {
                inQuotes.toggle()
                buffer.append(character)
                continue
            }

            if character == ",", !inQuotes {
                tokens.append(buffer.trimmingCharacters(in: .whitespaces))
                buffer = ""
                continue
            }

            buffer.append(character)
        }

        if !buffer.trimmingCharacters(in: .whitespaces).isEmpty {
            tokens.append(buffer.trimmingCharacters(in: .whitespaces))
        }

        return tokens
    }

    private func parseTokenBytes(_ token: String) -> [UInt8] {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 {
            let start = trimmed.index(after: trimmed.startIndex)
            let end = trimmed.index(before: trimmed.endIndex)
            let content = String(trimmed[start..<end])
            return Array(content.utf8)
        }

        if trimmed.hasPrefix("'"), trimmed.hasSuffix("'"), trimmed.count >= 3 {
            let start = trimmed.index(after: trimmed.startIndex)
            let end = trimmed.index(before: trimmed.endIndex)
            let content = String(trimmed[start..<end])
            if let first = content.utf8.first {
                return [first]
            }
            return []
        }

        if let byte = parseByteToken(trimmed) {
            return [byte]
        }

        return []
    }

    private func parseIncbinBytes(_ payload: String, relativeTo fileURL: URL) -> [UInt8] {
        guard let firstQuote = payload.firstIndex(of: "\"") else { return [] }
        guard let secondQuote = payload[payload.index(after: firstQuote)...].firstIndex(of: "\"") else { return [] }

        let relativePath = String(payload[payload.index(after: firstQuote)..<secondQuote])
        guard let data = resolveIncbinData(relativePath: relativePath, relativeTo: fileURL) else {
            return []
        }

        let remainder = payload[payload.index(after: secondQuote)...]
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: ","))
            .trimmingCharacters(in: .whitespaces)

        guard !remainder.isEmpty else {
            return [UInt8](data)
        }

        let params = remainder.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let offset = params.first.flatMap(parseIntegerToken) ?? 0
        let size = params.dropFirst().first.flatMap(parseIntegerToken)

        guard offset < data.count else { return [] }

        let available = data.count - offset
        let requested = size.map { max(0, min($0, available)) } ?? available
        let slice = data.subdata(in: offset..<(offset + requested))
        return [UInt8](slice)
    }

    private func resolveIncbinData(relativePath: String, relativeTo fileURL: URL) -> Data? {
        let baseDirectory = fileURL.deletingLastPathComponent()
        let localCandidate = baseDirectory.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: localCandidate.path()),
           let data = try? Data(contentsOf: localCandidate) {
            return data
        }

        var candidates: [URL] = [localCandidate]

        if let sourceRoot = nearestDirectory(containing: "bins.xml", startingAt: baseDirectory) {
            candidates.append(sourceRoot.appendingPathComponent(relativePath))

            let projectRoot = sourceRoot.deletingLastPathComponent()
            candidates.append(projectRoot.appendingPathComponent("bin").appendingPathComponent(relativePath))
            candidates.append(projectRoot.appendingPathComponent("src").appendingPathComponent(relativePath))
        }

        var seenPaths = Set<String>()
        for url in candidates where seenPaths.insert(url.path()).inserted {
            guard FileManager.default.fileExists(atPath: url.path()) else { continue }
            if let data = try? Data(contentsOf: url) {
                return data
            }
        }

        return nil
    }

    private func nearestDirectory(containing fileName: String, startingAt directory: URL) -> URL? {
        let fileManager = FileManager.default
        var currentPath = directory.standardizedFileURL.path
        var seenPaths = Set<String>()

        while seenPaths.insert(currentPath).inserted {
            let candidatePath = (currentPath as NSString).appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: candidatePath) {
                return URL(fileURLWithPath: currentPath, isDirectory: true)
            }

            let parentPath = (currentPath as NSString).deletingLastPathComponent
            if parentPath.isEmpty || parentPath == currentPath {
                break
            }
            currentPath = parentPath
        }

        return nil
    }

    private func parseByteToken(_ token: String) -> UInt8? {
        guard let parsed = parseIntegerToken(token), (-128...255).contains(parsed) else {
            return nil
        }
        return UInt8(truncatingIfNeeded: parsed)
    }

    private func parseIntegerToken(_ token: String) -> Int? {
        var value = token.trimmingCharacters(in: .whitespaces)
        while value.hasPrefix("#") || value.hasPrefix("<") || value.hasPrefix(">") {
            value.removeFirst()
        }

        guard !value.isEmpty else { return nil }

        if value.hasPrefix("$") {
            return Int(value.dropFirst(), radix: 16)
        }

        if value.lowercased().hasPrefix("0x") {
            return Int(value.dropFirst(2), radix: 16)
        }

        if value.hasPrefix("%") {
            return Int(value.dropFirst(), radix: 2)
        }

        return Int(value)
    }
}
