import Foundation

struct ASMSelectionSpec: Sendable {
    let exactLabels: [String]
    let containsKeywords: [String]
    let fileHints: [String]
    let maxBlocks: Int?

    init(
        exactLabels: [String],
        containsKeywords: [String],
        fileHints: [String] = [],
        maxBlocks: Int? = nil
    ) {
        self.exactLabels = exactLabels
        self.containsKeywords = containsKeywords
        self.fileHints = fileHints
        self.maxBlocks = maxBlocks
    }
}

enum ASMLabelSelector {
    static func selectBlocks(from blocks: [ASMByteBlock], specs: [ASMSelectionSpec]) -> [ASMByteBlock] {
        for spec in specs {
            let candidates = selectBlocks(
                from: blocks,
                exactLabels: spec.exactLabels,
                containsKeywords: spec.containsKeywords,
                fileHints: spec.fileHints
            )
            if !candidates.isEmpty {
                if let maxBlocks = spec.maxBlocks {
                    return Array(candidates.prefix(maxBlocks))
                }
                return candidates
            }
        }
        return []
    }

    static func collectBytes(from blocks: [ASMByteBlock], specs: [ASMSelectionSpec]) -> [UInt8] {
        for spec in specs {
            let bytes = collectBytes(
                from: blocks,
                exactLabels: spec.exactLabels,
                containsKeywords: spec.containsKeywords,
                fileHints: spec.fileHints,
                maxBlocks: spec.maxBlocks
            )
            if !bytes.isEmpty {
                return bytes
            }
        }
        return []
    }

    static func collectBytes(
        from blocks: [ASMByteBlock],
        exactLabels: [String],
        containsKeywords: [String],
        fileHints: [String] = [],
        maxBlocks: Int? = nil
    ) -> [UInt8] {
        let selected = selectBlocks(
            from: blocks,
            exactLabels: exactLabels,
            containsKeywords: containsKeywords,
            fileHints: fileHints
        )

        if selected.isEmpty {
            return []
        }

        return flatten(selected, maxBlocks: maxBlocks)
    }

    static func selectBlocks(
        from blocks: [ASMByteBlock],
        exactLabels: [String],
        containsKeywords: [String],
        fileHints: [String] = []
    ) -> [ASMByteBlock] {
        let normalizedExactOrdered = exactLabels.map { normalize($0) }
        let normalizedExact = Set(normalizedExactOrdered)
        let exactPriority = Dictionary(uniqueKeysWithValues: normalizedExactOrdered.enumerated().map { ($1, $0) })
        let normalizedKeywords = containsKeywords.map { normalize($0) }
        let normalizedFileHints = fileHints.map { normalize($0) }

        let exactMatches = blocks.filter { block in
            normalizedExact.contains(normalize(block.label))
        }

        if !exactMatches.isEmpty {
            if !normalizedFileHints.isEmpty {
                let hintedExact = exactMatches.filter { block in
                    let file = normalize(block.fileURL.lastPathComponent)
                    return normalizedFileHints.contains { file.contains($0) }
                }
                if !hintedExact.isEmpty {
                    return sortExactBlocks(hintedExact, exactPriority: exactPriority)
                }
            }
            return sortExactBlocks(exactMatches, exactPriority: exactPriority)
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
            return sortBlocks(hintedMatches)
        }

        let looseMatches = blocks.filter { block in
            let key = normalize(block.label) + " " + normalize(block.fileURL.lastPathComponent)
            return normalizedKeywords.contains { key.contains($0) }
        }

        return sortBlocks(looseMatches)
    }

    private static func sortExactBlocks(_ blocks: [ASMByteBlock], exactPriority: [String: Int]) -> [ASMByteBlock] {
        blocks.sorted { lhs, rhs in
            let lhsPriority = exactPriority[normalize(lhs.label)] ?? Int.max
            let rhsPriority = exactPriority[normalize(rhs.label)] ?? Int.max
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            if lhs.bytes.count != rhs.bytes.count {
                return lhs.bytes.count > rhs.bytes.count
            }
            return lhs.label < rhs.label
        }
    }

    private static func sortBlocks(_ blocks: [ASMByteBlock]) -> [ASMByteBlock] {
        blocks.sorted { lhs, rhs in
            if lhs.bytes.count != rhs.bytes.count {
                return lhs.bytes.count > rhs.bytes.count
            }
            return lhs.label < rhs.label
        }
    }

    private static func flatten(_ blocks: [ASMByteBlock], maxBlocks: Int?) -> [UInt8] {
        let slice: ArraySlice<ASMByteBlock>
        if let maxBlocks {
            slice = blocks.prefix(maxBlocks)
        } else {
            slice = blocks[...]
        }

        return slice.flatMap(\.bytes)
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
