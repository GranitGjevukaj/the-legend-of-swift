import Foundation

public struct CaveState: Codable, Equatable, Sendable {
    public static let exitColumns = 6...9
    public static let spawnPosition = Position(x: 120, y: Room.pixelHeight - 32)

    public var parentScreen: ScreenCoordinate
    public var entrance: CaveEntrance

    public init(parentScreen: ScreenCoordinate, entrance: CaveEntrance) {
        self.parentScreen = parentScreen
        self.entrance = entrance
    }

    public var room: Room {
        Self.room(parentScreen: parentScreen)
    }

    public func shouldExit(candidate: Position, direction: Direction) -> Bool {
        guard direction == .down else {
            return false
        }

        let tileColumn = candidate.x / Room.tileSize
        return candidate.y >= (Room.pixelHeight - Room.tileSize - 8) && Self.exitColumns.contains(tileColumn)
    }

    public static func room(parentScreen: ScreenCoordinate) -> Room {
        var walkable = Array(repeating: true, count: Room.columns * Room.rows)

        for row in 0..<Room.rows {
            for column in 0..<Room.columns {
                let index = row * Room.columns + column
                let isSideWall = column == 0 || column == Room.columns - 1
                let isTopWall = row == 0
                let isBottomWall = row == Room.rows - 1 && !exitColumns.contains(column)

                if isSideWall || isTopWall || isBottomWall {
                    walkable[index] = false
                }
            }
        }

        return Room(coordinate: parentScreen, collisionMask: walkable)
    }
}

public struct CavePickup: Codable, Equatable, Sendable {
    public var slot: Int
    public var kind: ItemDefinition.Kind

    public init(slot: Int, kind: ItemDefinition.Kind) {
        self.slot = slot
        self.kind = kind
    }

    public var position: Position {
        let wareXs = [0x58, 0x78, 0x98]
        let x = wareXs[min(max(0, slot), wareXs.count - 1)]
        let relativeY = max(0, 0x98 - 0x40)
        return Position(x: x, y: Room.pixelHeight - relativeY)
    }

    public func contains(pixelPosition: Position) -> Bool {
        abs(pixelPosition.x - position.x) <= 8 && abs(pixelPosition.y - position.y) <= 8
    }
}
