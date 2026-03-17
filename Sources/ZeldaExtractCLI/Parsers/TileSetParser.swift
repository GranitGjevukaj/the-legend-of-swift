import Foundation
import ZeldaContent

struct TileSetArtifacts {
    let tileSet: TileSet
    let binary: Data
}

struct TileSetParser {
    private let repository = ASMByteRepository()

    func parse(from sourceURL: URL?) -> TileSetArtifacts {
        let blocks = repository.load(from: sourceURL)
        let rawBytes = collectTileBytes(from: blocks)
        let bytes = normalizedBytes(from: rawBytes)

        let tileCount = min(64, max(16, bytes.count / 64))
        let tiles: [TileSet.Tile] = (0..<tileCount).map { tileIndex in
            let start = tileIndex * 64
            let end = min(bytes.count, start + 64)
            let slice = bytes[start..<end]
            if slice.count < 64 {
                return TileSet.Tile(id: tileIndex, pixels: Array(slice) + Array(repeating: 0, count: 64 - slice.count))
            }
            return TileSet.Tile(id: tileIndex, pixels: Array(slice))
        }

        return TileSetArtifacts(tileSet: TileSet(id: "overworld", tiles: tiles), binary: Data(bytes))
    }

    private func collectTileBytes(from blocks: [ASMByteBlock]) -> [UInt8] {
        let selected = ASMLabelSelector.collectBytes(
            from: blocks,
            exactLabels: [
                "TilePatternData",
                "OverworldTilePatterns",
                "OverworldCHRData",
                "ChrDataBank6",
                "BackgroundCHRData"
            ],
            containsKeywords: ["tile", "chr", "pattern", "sprite"],
            fileHints: ["chr", "tiles", "bank6"],
            maxBlocks: 8
        )

        if !selected.isEmpty {
            return selected
        }

        return blocks
            .sorted { lhs, rhs in lhs.bytes.count > rhs.bytes.count }
            .prefix(4)
            .flatMap(\.bytes)
    }

    private func normalizedBytes(from bytes: [UInt8]) -> [UInt8] {
        if bytes.isEmpty {
            return fallbackBytes()
        }

        if bytes.count >= 4096 {
            return Array(bytes.prefix(4096))
        }

        var expanded = bytes
        while expanded.count < 4096 {
            expanded.append(contentsOf: bytes)
        }
        return Array(expanded.prefix(4096))
    }

    private func fallbackBytes() -> [UInt8] {
        (0..<4096).map { index in UInt8(index % 4) }
    }

}
