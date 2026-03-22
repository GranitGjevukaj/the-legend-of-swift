import Foundation
import ZeldaContent
import ZeldaCore

enum OverworldContentBuilder {
    static func build(from data: OverworldData?) -> Overworld {
        var overworld = Overworld(
            rooms: [:],
            enemySpawns: [:],
            caveEntrances: [:],
            roomFlags: [:],
            cavePickups: [:],
            roomConnections: [:]
        )
        guard let data else {
            return Overworld.starterOverworld()
        }

        var roomConnections: [ScreenCoordinate: Set<Direction>] = [:]
        let availableCoordinates = Set(
            data.screens.map { ScreenCoordinate(column: $0.column, row: $0.row) }
        )

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

            for exit in screen.exits {
                guard let direction = parseDirection(from: exit) else {
                    continue
                }

                guard let destination = linkedCoordinate(
                    from: coordinate,
                    direction: direction,
                    width: data.width,
                    height: data.height
                ),
                    availableCoordinates.contains(destination)
                else {
                    continue
                }

                roomConnections[coordinate, default: []].insert(direction)
                roomConnections[destination, default: []].insert(direction.opposite)
            }

            if let caveIndex = screen.caveIndex,
               let definition = data.caveDefinitions?.first(where: { $0.index == caveIndex })
            {
                overworld.cavePickups[coordinate] = definition.items.compactMap { item in
                    guard item.price == 0 else {
                        return nil
                    }
                    guard let itemId = item.itemId, let kind = itemKind(for: itemId) else {
                        return nil
                    }
                    return CavePickup(slot: item.slot, kind: kind)
                }
            }
        }

        overworld.roomConnections = roomConnections
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

    private static func linkedCoordinate(
        from coordinate: ScreenCoordinate,
        direction: Direction,
        width: Int,
        height: Int
    ) -> ScreenCoordinate? {
        switch direction {
        case .up:
            let row = coordinate.row - 1
            guard row >= 0 else { return nil }
            return ScreenCoordinate(column: coordinate.column, row: row)
        case .down:
            let row = coordinate.row + 1
            guard row < height else { return nil }
            return ScreenCoordinate(column: coordinate.column, row: row)
        case .left:
            let column = coordinate.column - 1
            guard column >= 0 else { return nil }
            return ScreenCoordinate(column: column, row: coordinate.row)
        case .right:
            let column = coordinate.column + 1
            guard column < width else { return nil }
            return ScreenCoordinate(column: column, row: coordinate.row)
        }
    }

    private static func parseDirection(from exit: String) -> Direction? {
        switch exit.lowercased() {
        case "up", "north":
            return .up
        case "down", "south":
            return .down
        case "left", "west":
            return .left
        case "right", "east":
            return .right
        default:
            return nil
        }
    }
}
