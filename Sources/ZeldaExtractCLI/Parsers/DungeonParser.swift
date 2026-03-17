import Foundation
import ZeldaContent

struct DungeonParser {
    private let repository = ASMByteRepository()
    private let enemyCatalog = ["stalfos", "gibdo", "octorok", "tektite", "wizzrobe", "darknut"]

    func parse(from sourceURL: URL?) -> [DungeonData] {
        let blocks = repository.load(from: sourceURL)
        let dungeonBytes = collectDungeonBytes(from: blocks)

        guard !dungeonBytes.isEmpty else {
            return fallbackDungeons()
        }

        return (1...9).map { level in
            let rooms = (0..<16).map { roomIndex in
                let base = ((level - 1) * 16 + roomIndex) * 3
                let doorByte = dungeonBytes[base % dungeonBytes.count]
                let enemyA = dungeonBytes[(base + 1) % dungeonBytes.count]
                let enemyB = dungeonBytes[(base + 2) % dungeonBytes.count]

                return DungeonRoom(
                    id: "D\(level)_R\(roomIndex)",
                    doors: parseDoors(from: doorByte),
                    enemies: [enemyName(for: enemyA), enemyName(for: enemyB)]
                )
            }
            return DungeonData(level: level, rooms: rooms)
        }
    }

    private func parseDoors(from value: UInt8) -> [String] {
        var doors: [String] = []
        if value & 0b0001 != 0 { doors.append("north") }
        if value & 0b0010 != 0 { doors.append("south") }
        if value & 0b0100 != 0 { doors.append("west") }
        if value & 0b1000 != 0 { doors.append("east") }

        if doors.isEmpty {
            doors = ["north", "south"]
        }

        return doors
    }

    private func enemyName(for value: UInt8) -> String {
        enemyCatalog[Int(value) % enemyCatalog.count]
    }

    private func collectDungeonBytes(from blocks: [ASMByteBlock]) -> [UInt8] {
        let selected = ASMLabelSelector.collectBytes(
            from: blocks,
            exactLabels: [
                "DungeonRoomData",
                "DungeonLayoutData",
                "LevelRoomData",
                "LevelLayoutData"
            ],
            containsKeywords: ["dungeon", "level", "room"],
            fileHints: ["dungeon", "bank3"],
            maxBlocks: 12
        )

        if selected.isEmpty {
            return []
        }
        return selected
    }

    private func fallbackDungeons() -> [DungeonData] {
        (1...9).map { level in
            let rooms = (0..<8).map { roomIndex in
                DungeonRoom(
                    id: "D\(level)_R\(roomIndex)_default",
                    doors: ["north", "south", "west", "east"],
                    enemies: ["stalfos", "gibdo"]
                )
            }
            return DungeonData(level: level, rooms: rooms)
        }
    }
}
