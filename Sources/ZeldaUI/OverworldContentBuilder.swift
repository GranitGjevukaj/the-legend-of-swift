import Foundation
import ZeldaContent
import ZeldaCore

enum OverworldContentBuilder {
    static func build(from data: OverworldData?) -> Overworld {
        var overworld = Overworld.starterOverworld()
        guard let data else {
            return overworld
        }

        for screen in data.screens {
            let coordinate = ScreenCoordinate(column: screen.column, row: screen.row)
            let roomFlags = screen.roomFlags ?? 0
            var collisionMask = Array(repeating: false, count: Room.columns * Room.rows)
            var caveEntrances: [CaveEntrance] = []

            for row in 0..<Room.rows {
                for column in 0..<Room.columns {
                    let sourceIndex = row * Room.columns + column
                    guard screen.metatileGrid.indices.contains(sourceIndex) else { continue }

                    let descriptor = screen.metatileGrid[sourceIndex]
                    collisionMask[sourceIndex] = OverworldSquareDecoder.isWalkable(
                        descriptor: descriptor,
                        roomFlags: roomFlags
                    )

                    if OverworldSquareDecoder.isCaveEntrance(descriptor: descriptor, roomFlags: roomFlags) {
                        let exitPosition: Position?
                        if let exitX = screen.undergroundExitX, let exitY = screen.undergroundExitY {
                            exitPosition = Position(x: exitX, y: exitY)
                        } else {
                            exitPosition = nil
                        }

                        caveEntrances.append(
                            CaveEntrance(
                                tileColumn: column,
                                tileRow: row,
                                tileWidth: 2,
                                exteriorSpawnOverride: exitPosition
                            )
                        )
                    }
                }
            }
            overworld.rooms[coordinate] = Room(coordinate: coordinate, collisionMask: collisionMask)
            overworld.caveEntrances[coordinate] = caveEntrances
            overworld.roomFlags[coordinate] = roomFlags

            if let caveIndex = screen.caveIndex,
               let definition = data.caveDefinitions?.first(where: { $0.index == caveIndex })
            {
                overworld.cavePickups[coordinate] = definition.items.compactMap { item in
                    guard let itemId = item.itemId, let kind = itemKind(for: itemId) else {
                        return nil
                    }
                    return CavePickup(slot: item.slot, kind: kind)
                }
            }
        }

        return overworld
    }

    private static func itemKind(for itemId: Int) -> ItemDefinition.Kind? {
        switch itemId {
        case 0x01: return .woodenSword
        case 0x02: return .whiteSword
        case 0x03: return .magicSword
        case 0x1F: return .boomerang
        case 0x20: return .boomerang
        case 0x05: return .bomb
        case 0x06: return .candle
        case 0x1D: return .bow
        default: return nil
        }
    }
}
