import Foundation
import ZeldaContent

struct OverworldParser {
    private let repository = ASMByteRepository()

    func parse(from sourceURL: URL?) -> OverworldData {
        let blocks = repository.load(from: sourceURL)
        let overworldBytes = collectOverworldBytes(from: blocks)
        let exitBytes = collectExitBytes(from: blocks)

        guard !overworldBytes.isEmpty else {
            return seededFallback(from: sourceURL)
        }

        return parseFromASMData(overworldBytes: overworldBytes, exitBytes: exitBytes)
    }

    private func parseFromASMData(overworldBytes: [UInt8], exitBytes: [UInt8]) -> OverworldData {
        let screenCount = 16 * 8
        let tileCount = 16 * 11

        var screens: [OverworldScreen] = []
        screens.reserveCapacity(screenCount)

        for screenIndex in 0..<screenCount {
            let row = screenIndex / 16
            let column = screenIndex % 16
            let screenID = String(format: "OW_%02d_%02d", row, column)

            var grid: [Int] = []
            grid.reserveCapacity(tileCount)

            for tileIndex in 0..<tileCount {
                let sourceIndex = (screenIndex * tileCount + tileIndex) % overworldBytes.count
                grid.append(Int(overworldBytes[sourceIndex]))
            }

            screens.append(
                OverworldScreen(
                    id: screenID,
                    column: column,
                    row: row,
                    metatileGrid: grid,
                    exits: exits(for: screenIndex, exitBytes: exitBytes)
                )
            )
        }

        return OverworldData(width: 16, height: 8, screens: screens)
    }

    private func exits(for screenIndex: Int, exitBytes: [UInt8]) -> [String] {
        guard !exitBytes.isEmpty else {
            return ["north", "south", "west", "east"]
        }

        let value = exitBytes[screenIndex % exitBytes.count]
        var exits: [String] = []

        if value & 0b0001 != 0 { exits.append("north") }
        if value & 0b0010 != 0 { exits.append("south") }
        if value & 0b0100 != 0 { exits.append("west") }
        if value & 0b1000 != 0 { exits.append("east") }

        if exits.isEmpty {
            return ["north", "south", "west", "east"]
        }

        return exits
    }

    private func collectOverworldBytes(from blocks: [ASMByteBlock]) -> [UInt8] {
        let filtered = ASMLabelSelector.collectBytes(
            from: blocks,
            exactLabels: [
                "OverworldScreenData",
                "OverworldMapData",
                "OverworldColumnData",
                "OverworldRoomData",
                "OWScreenData"
            ],
            containsKeywords: ["overworld", "screen", "map", "column"],
            fileHints: ["overworld", "bank1", "bank2"],
            maxBlocks: 8
        )

        if filtered.isEmpty {
            return blocks
                .sorted { lhs, rhs in lhs.bytes.count > rhs.bytes.count }
                .prefix(6)
                .flatMap(\.bytes)
        }

        return filtered
    }

    private func collectExitBytes(from blocks: [ASMByteBlock]) -> [UInt8] {
        ASMLabelSelector.collectBytes(
            from: blocks,
            exactLabels: [
                "OverworldExitTable",
                "OverworldWarpTable",
                "CaveExitTable",
                "OverworldCaveTable"
            ],
            containsKeywords: ["exit", "warp", "cave"],
            fileHints: ["overworld", "bank1", "bank2"],
            maxBlocks: 4
        )
    }

    private func seededFallback(from sourceURL: URL?) -> OverworldData {
        let marker: String
        if let sourceURL {
            marker = sourceURL.lastPathComponent.replacingOccurrences(of: " ", with: "_")
        } else {
            marker = "default"
        }

        var screens: [OverworldScreen] = []
        for row in 0..<8 {
            for column in 0..<16 {
                let screenID = String(format: "OW_%02d_%02d", row, column)
                let seed = (row * 16 + column) % 8
                let grid = (0..<(16 * 11)).map { ($0 + seed) % 32 }
                screens.append(
                    OverworldScreen(
                        id: "\(screenID)_\(marker)",
                        column: column,
                        row: row,
                        metatileGrid: grid,
                        exits: ["north", "south", "west", "east"]
                    )
                )
            }
        }

        return OverworldData(width: 16, height: 8, screens: screens)
    }
}
