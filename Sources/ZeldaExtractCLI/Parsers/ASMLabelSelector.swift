import Foundation

enum ASMLabelSelector {
    static func collectBytes(
        from blocks: [ASMByteBlock],
        exactLabels: [String],
        containsKeywords: [String],
        fileHints: [String] = [],
        maxBlocks: Int? = nil
    ) -> [UInt8] {
        let normalizedExact = Set(exactLabels.map { normalize($0) })
        let normalizedKeywords = containsKeywords.map { normalize($0) }
        let normalizedFileHints = fileHints.map { normalize($0) }

        let exactMatches = blocks.filter { block in
            normalizedExact.contains(normalize(block.label))
        }

        if !exactMatches.isEmpty {
            return flatten(exactMatches, maxBlocks: maxBlocks)
        }

        let hintedMatches = blocks.filter { block in
            let label = normalize(block.label)
            let file = normalize(block.fileURL.lastPathComponent)

            let hasKeyword = normalizedKeywords.contains { label.contains($0) || file.contains($0) }
            guard hasKeyword else { return false }

            if normalizedFileHints.isEmpty {
                return true
            }

            return normalizedFileHints.contains { file.contains($0) }
        }

        if !hintedMatches.isEmpty {
            return flatten(hintedMatches, maxBlocks: maxBlocks)
        }

        let looseMatches = blocks.filter { block in
            let key = normalize(block.label) + " " + normalize(block.fileURL.lastPathComponent)
            return normalizedKeywords.contains { key.contains($0) }
        }

        return flatten(looseMatches, maxBlocks: maxBlocks)
    }

    private static func flatten(_ blocks: [ASMByteBlock], maxBlocks: Int?) -> [UInt8] {
        let sorted = blocks.sorted { lhs, rhs in
            if lhs.bytes.count != rhs.bytes.count {
                return lhs.bytes.count > rhs.bytes.count
            }
            return lhs.label < rhs.label
        }

        let slice: ArraySlice<ASMByteBlock>
        if let maxBlocks {
            slice = sorted.prefix(maxBlocks)
        } else {
            slice = sorted[...]
        }

        return slice.flatMap(\.bytes)
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
