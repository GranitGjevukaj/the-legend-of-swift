import Foundation
import ZeldaContent

struct PaletteParser {
    private let repository = ASMByteRepository()

    func parse(from sourceURL: URL?) -> PaletteBundle {
        let blocks = repository.load(from: sourceURL)
        let paletteBytes = ASMLabelSelector.collectBytes(from: blocks, specs: ZeldaDisassemblySymbols.paletteData)
        let paletteBlocks = blocks.filter { searchableKey(for: $0).contains("pal") || searchableKey(for: $0).contains("palette") }
        let combinedSource = paletteBytes.isEmpty ? paletteBlocks.flatMap(\.bytes) : paletteBytes
        let combined = combinedSource.map { Int($0 & 0x3F) }

        let areaPalettes = [
            "overworld": palette(preferred: ["overworld", "ow"], fallbackChunk: 0, blocks: paletteBlocks, combined: combined, defaultValue: [15, 17, 33, 45]),
            "dungeon_1": palette(preferred: ["dungeon", "level1", "dng1"], fallbackChunk: 1, blocks: paletteBlocks, combined: combined, defaultValue: [15, 1, 17, 32]),
            "dungeon_9": palette(preferred: ["dungeon9", "level9", "dng9"], fallbackChunk: 2, blocks: paletteBlocks, combined: combined, defaultValue: [15, 6, 22, 38])
        ]

        let spritePalettes = [
            "link": palette(preferred: ["link", "player"], fallbackChunk: 3, blocks: paletteBlocks, combined: combined, defaultValue: [15, 30, 44, 57]),
            "enemies": palette(preferred: ["enemy", "monster"], fallbackChunk: 4, blocks: paletteBlocks, combined: combined, defaultValue: [15, 10, 25, 40])
        ]

        return PaletteBundle(nesColors: Self.defaultNESRGBPalette, areaPalettes: areaPalettes, spritePalettes: spritePalettes)
    }

    private func palette(
        preferred keywords: [String],
        fallbackChunk: Int,
        blocks: [ASMByteBlock],
        combined: [Int],
        defaultValue: [Int]
    ) -> [Int] {
        let preferredBlock = blocks.first { block in
            let key = searchableKey(for: block)
            return keywords.contains { key.contains($0) }
        }

        if let preferredBlock {
            let values = preferredBlock.bytes.map { Int($0 & 0x3F) }
            if values.count >= 4 {
                return Array(values.prefix(4))
            }
        }

        let start = fallbackChunk * 4
        if combined.count >= start + 4 {
            return Array(combined[start..<(start + 4)])
        }

        return defaultValue
    }

    private func searchableKey(for block: ASMByteBlock) -> String {
        "\(block.label.lowercased()) \(block.fileURL.lastPathComponent.lowercased())"
    }
}

private extension PaletteParser {
    static let defaultNESRGBPalette = [
        "#7C7C7C", "#0000FC", "#0000BC", "#4428BC", "#940084", "#A80020", "#A81000", "#881400",
        "#503000", "#007800", "#006800", "#005800", "#004058", "#000000", "#000000", "#000000",
        "#BCBCBC", "#0078F8", "#0058F8", "#6844FC", "#D800CC", "#E40058", "#F83800", "#E45C10",
        "#AC7C00", "#00B800", "#00A800", "#00A844", "#008888", "#000000", "#000000", "#000000",
        "#F8F8F8", "#3CBCFC", "#6888FC", "#9878F8", "#F878F8", "#F85898", "#F87858", "#FCA044",
        "#F8B800", "#B8F818", "#58D854", "#58F898", "#00E8D8", "#787878", "#000000", "#000000",
        "#FCFCFC", "#A4E4FC", "#B8B8F8", "#D8B8F8", "#F8B8F8", "#F8A4C0", "#F0D0B0", "#FCE0A8",
        "#F8D878", "#D8F878", "#B8F8B8", "#B8F8D8", "#00FCFC", "#F8D8F8", "#000000", "#000000"
    ]
}
