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

        let tileCount = max(16, min(256, bytes.count / 16))
        let tiles: [TileSet.Tile] = (0..<tileCount).map { tileIndex in
            let start = tileIndex * 16
            let end = min(bytes.count, start + 16)
            let slice = Array(bytes[start..<end])
            return TileSet.Tile(id: tileIndex, pixels: decodeTile(slice))
        }

        return TileSetArtifacts(tileSet: TileSet(id: "overworld", tiles: tiles), binary: Data(bytes))
    }

    private func collectTileBytes(from blocks: [ASMByteBlock]) -> [UInt8] {
        if let structured = structuredOverworldTileBytes(from: blocks) {
            return structured
        }

        let selected = ASMLabelSelector.collectBytes(from: blocks, specs: ZeldaDisassemblySymbols.tileData)

        if !selected.isEmpty {
            return selected
        }

        return blocks
            .sorted { lhs, rhs in lhs.bytes.count > rhs.bytes.count }
            .prefix(4)
            .flatMap(\.bytes)
    }

    private func structuredOverworldTileBytes(from blocks: [ASMByteBlock]) -> [UInt8]? {
        let requiredOrder = [
            ("CommonBackgroundPatterns", "z_02"),
            ("PatternBlockOWBG", "z_03"),
            ("CommonMiscPatterns", "z_02")
        ]

        var combined: [UInt8] = []
        combined.reserveCapacity(4096)

        for (label, fileHint) in requiredOrder {
            guard let bytes = bytes(for: label, preferredFileHint: fileHint, in: blocks) else {
                return nil
            }
            combined.append(contentsOf: bytes)
        }

        guard combined.count >= 4096 else {
            return nil
        }

        return Array(combined.prefix(4096))
    }

    private func bytes(for label: String, preferredFileHint: String, in blocks: [ASMByteBlock]) -> [UInt8]? {
        let normalizedTarget = label.lowercased()
        let matches = blocks.filter { $0.label.lowercased() == normalizedTarget }
        guard !matches.isEmpty else { return nil }

        if let hinted = matches.first(where: { $0.fileURL.lastPathComponent.lowercased().contains(preferredFileHint) }) {
            return hinted.bytes
        }

        return matches.first?.bytes
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
        var bytes: [UInt8] = []
        bytes.reserveCapacity(4096)

        for tile in 0..<256 {
            for row in 0..<8 {
                let stripe = ((tile + row) % 2 == 0) ? UInt8(0b10101010) : UInt8(0b01010101)
                let lowPlane = UInt8(truncatingIfNeeded: stripe ^ UInt8((tile * 13 + row * 7) & 0xFF))
                bytes.append(lowPlane)
            }
            for row in 0..<8 {
                let highPlane = UInt8(truncatingIfNeeded: ((tile * 5) + (row * 17)) & 0xFF)
                bytes.append(highPlane)
            }
        }

        return bytes
    }

    private func decodeTile(_ tileBytes: [UInt8]) -> [UInt8] {
        let padded = tileBytes + Array(repeating: 0, count: max(0, 16 - tileBytes.count))
        var pixels = Array(repeating: UInt8(0), count: 64)

        for row in 0..<8 {
            let low = padded[row]
            let high = padded[row + 8]
            for column in 0..<8 {
                let bit = 7 - column
                let lowBit = (low >> bit) & 0x01
                let highBit = (high >> bit) & 0x01
                pixels[(row * 8) + column] = lowBit | (highBit << 1)
            }
        }

        return pixels
    }

}
