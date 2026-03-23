import Foundation
import ZeldaContent

struct TitleScreenParser {
    private let repository = ASMByteRepository()

    func parse(from sourceURL: URL?) -> TitleScreenData {
        let blocks = repository.load(from: sourceURL)

        guard
            let titleTransfer = bytes(for: "GameTitleTransferBuf", in: blocks),
            let titlePaletteTransfer = bytes(for: "TitlePaletteTransferRecord", in: blocks)
        else {
            return fallbackTitleScreen()
        }

        let vram = applyTileTransferRecord(titleTransfer)
        let paletteRam = applyPaletteTransferRecord(titlePaletteTransfer)
        let patternTable = assembleBackgroundPatternTable(from: blocks)

        let nametableLength = 32 * 30
        let attributeTableLength = 64
        guard
            vram.count >= 0x400,
            vram.count >= nametableLength + attributeTableLength
        else {
            return fallbackTitleScreen()
        }

        let nametable = Array(vram[..<nametableLength])
        let attributes = Array(vram[nametableLength..<(nametableLength + attributeTableLength)])
        let normalizedPaletteRam = normalizePaletteRam(paletteRam)

        return TitleScreenData(
            tileColumns: 32,
            tileRows: 30,
            nametable: nametable,
            attributeTable: attributes,
            paletteRam: normalizedPaletteRam,
            backgroundPatternTable: patternTable
        )
    }

    private func applyTileTransferRecord(_ record: [UInt8]) -> [UInt8] {
        // Keep a full nametable window (0x2000-0x2FFF), then use the first table
        // as the base title viewport.
        var vram = Array(repeating: UInt8(0x24), count: 0x1000)
        var cursor = 0

        while cursor < record.count {
            let marker = record[cursor]
            if marker == 0xFF {
                break
            }

            guard cursor + 2 < record.count else {
                break
            }

            let address = (Int(record[cursor]) << 8) | Int(record[cursor + 1])
            let count = Int(record[cursor + 2])
            cursor += 3

            guard count > 0 else {
                continue
            }

            let available = min(count, record.count - cursor)
            let baseOffset = address - 0x2000

            for index in 0..<available {
                let destination = baseOffset + index
                guard vram.indices.contains(destination) else {
                    continue
                }
                vram[destination] = record[cursor + index]
            }

            cursor += available
        }

        return vram
    }

    private func applyPaletteTransferRecord(_ record: [UInt8]) -> [UInt8] {
        var paletteRam = Array(repeating: UInt8(0), count: 32)
        var cursor = 0

        while cursor < record.count {
            let marker = record[cursor]
            if marker == 0xFF {
                break
            }

            guard cursor + 2 < record.count else {
                break
            }

            let address = (Int(record[cursor]) << 8) | Int(record[cursor + 1])
            let count = Int(record[cursor + 2])
            cursor += 3

            guard count > 0 else {
                continue
            }

            let available = min(count, record.count - cursor)
            for index in 0..<available {
                let destinationAddress = address + index
                guard (0x3F00...0x3FFF).contains(destinationAddress) else {
                    continue
                }
                let destination = (destinationAddress - 0x3F00) & 0x1F
                paletteRam[destination] = record[cursor + index]
            }

            cursor += available
        }

        return paletteRam
    }

    private func assembleBackgroundPatternTable(from blocks: [ASMByteBlock]) -> [UInt8] {
        var table = Array(repeating: UInt8(0), count: 0x1000)

        if let commonBackground = bytes(for: "CommonBackgroundPatterns", in: blocks) {
            copy(commonBackground, into: &table, at: 0x0000)
        }

        if let demoBackground = bytes(for: "DemoBackgroundPatterns", in: blocks) {
            // Demo patterns are loaded at VRAM $1700, which is offset $700 into
            // the background pattern table selected for title mode.
            copy(demoBackground, into: &table, at: 0x0700)
        }

        if table.allSatisfy({ $0 == 0 }) {
            return fallbackPatternTable()
        }

        return table
    }

    private func normalizePaletteRam(_ paletteRam: [UInt8]) -> [UInt8] {
        var normalized = Array(repeating: UInt8(0), count: 32)
        for index in normalized.indices {
            normalized[index] = paletteRam[safe: index] ?? 0
        }
        return normalized
    }

    private func fallbackTitleScreen() -> TitleScreenData {
        TitleScreenData(
            tileColumns: 32,
            tileRows: 30,
            nametable: Array(repeating: 0x24, count: 32 * 30),
            attributeTable: Array(repeating: 0x00, count: 64),
            paletteRam: fallbackPaletteRam(),
            backgroundPatternTable: fallbackPatternTable()
        )
    }

    private func fallbackPaletteRam() -> [UInt8] {
        let head: [UInt8] = [
            0x36, 0x0F, 0x00, 0x10,
            0x36, 0x17, 0x27, 0x0F,
            0x36, 0x08, 0x1A, 0x28,
            0x36, 0x30, 0x3B, 0x22
        ]
        return head + Array(repeating: 0x0F, count: max(0, 32 - head.count))
    }

    private func fallbackPatternTable() -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(0x1000)

        for tile in 0..<256 {
            for row in 0..<8 {
                let stripe = ((tile + row) % 2 == 0) ? UInt8(0b10101010) : UInt8(0b01010101)
                let low = UInt8(truncatingIfNeeded: stripe ^ UInt8((tile * 11 + row * 5) & 0xFF))
                bytes.append(low)
            }
            for row in 0..<8 {
                let high = UInt8(truncatingIfNeeded: (tile * 3 + row * 17) & 0xFF)
                bytes.append(high)
            }
        }

        return Array(bytes.prefix(0x1000))
    }

    private func copy(_ source: [UInt8], into target: inout [UInt8], at offset: Int) {
        guard offset < target.count else { return }
        let maxCount = min(source.count, target.count - offset)
        guard maxCount > 0 else { return }
        target.replaceSubrange(offset..<(offset + maxCount), with: source.prefix(maxCount))
    }

    private func bytes(for label: String, in blocks: [ASMByteBlock]) -> [UInt8]? {
        let normalizedLabel = normalize(label)
        let matches = blocks.filter { normalize($0.label) == normalizedLabel }
        guard !matches.isEmpty else {
            return nil
        }

        if let hinted = matches.first(where: { $0.fileURL.lastPathComponent.lowercased().contains("z_") }) {
            return hinted.bytes
        }

        return matches.first?.bytes
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
