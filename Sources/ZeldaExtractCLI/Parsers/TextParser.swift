import Foundation

struct TextParser {
    private let repository = ASMByteRepository()
    private let zeldaDecoder = ZeldaTextDecoder()

    func parseText(from sourceURL: URL?) -> [String: String] {
        let blocks = repository.load(from: sourceURL)
        let textBlocks = ASMLabelSelector.selectBlocks(from: blocks, specs: ZeldaDisassemblySymbols.textData)

        guard !textBlocks.isEmpty else {
            return fallbackText()
        }

        var entries: [String: String] = [:]
        for block in textBlocks {
            let lines = decodeLines(from: block.bytes)
            guard !lines.isEmpty else { continue }

            let key = normalizeKey(block.label)
            let value = lines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                entries[key] = value
            }
        }

        return entries.isEmpty ? fallbackText() : entries
    }

    func parseAudio(from sourceURL: URL?) -> [String: String] {
        let blocks = repository.load(from: sourceURL)
        let audioBlocks = ASMLabelSelector.selectBlocks(from: blocks, specs: ZeldaDisassemblySymbols.audioData)

        guard !audioBlocks.isEmpty else {
            return fallbackAudio()
        }

        var entries: [String: String] = [:]
        for block in audioBlocks {
            guard let first = block.bytes.first else { continue }
            let second = block.bytes.dropFirst().first ?? 0
            let third = block.bytes.dropFirst(2).first ?? 0

            let tempo = 80 + Int(first % 120)
            let instrument = instrumentName(for: second)
            let length = lengthName(for: third)
            entries[normalizeKey(block.label)] = "tempo:\(tempo);instrument:\(instrument);length:\(length)"
        }

        return entries.isEmpty ? fallbackAudio() : entries
    }

    private func decodeLines(from bytes: [UInt8]) -> [String] {
        var lines: [String] = []
        var current: [UInt8] = []

        for byte in bytes {
            if byte == 0 || byte == 0xFF {
                if !current.isEmpty {
                    let line = decodeASCII(current)
                    if !line.isEmpty { lines.append(line) }
                    current = []
                }
                continue
            }
            current.append(byte)
        }

        if !current.isEmpty {
            let line = decodeASCII(current)
            if !line.isEmpty { lines.append(line) }
        }

        return lines
    }

    private func decodeASCII(_ bytes: [UInt8]) -> String {
        zeldaDecoder.decodeLine(bytes)
    }

    private func normalizeKey(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: " ", with: "_")
    }

    private func instrumentName(for byte: UInt8) -> String {
        switch byte % 4 {
        case 0: return "pulse"
        case 1: return "triangle"
        case 2: return "noise"
        default: return "dpcm"
        }
    }

    private func lengthName(for byte: UInt8) -> String {
        switch byte % 3 {
        case 0: return "short"
        case 1: return "medium"
        default: return "long"
        }
    }

    private func fallbackText() -> [String: String] {
        [
            "old_man_sword": "IT'S DANGEROUS TO GO ALONE! TAKE THIS.",
            "moblin_secret": "IT'S A SECRET TO EVERYBODY.",
            "merchant_bait": "BUY SOMETHIN' WILL YA!",
            "dungeon_hint": "DODONGO DISLIKES SMOKE."
        ]
    }

    private func fallbackAudio() -> [String: String] {
        [
            "overworld_theme": "tempo:132;instrument:pulse",
            "dungeon_theme": "tempo:118;instrument:triangle",
            "boss_theme": "tempo:150;instrument:noise",
            "sfx_sword": "channel:pulse;length:short"
        ]
    }
}
