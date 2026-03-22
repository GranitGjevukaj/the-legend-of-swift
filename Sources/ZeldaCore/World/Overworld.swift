import Foundation

public struct CaveEntrance: Codable, Equatable, Sendable {
    public var tileColumn: Int
    public var tileRow: Int
    public var tileWidth: Int
    public var exteriorSpawnOverride: Position?

    public init(tileColumn: Int, tileRow: Int, tileWidth: Int = 1, exteriorSpawnOverride: Position? = nil) {
        self.tileColumn = tileColumn
        self.tileRow = tileRow
        self.tileWidth = max(1, tileWidth)
        self.exteriorSpawnOverride = exteriorSpawnOverride
    }

    public func contains(pixelPosition: Position) -> Bool {
        let minX = (tileColumn * Room.tileSize) - 4
        let maxX = ((tileColumn + tileWidth) * Room.tileSize) + 4
        let minY = (tileRow * Room.tileSize) - 8
        let maxY = ((tileRow + 1) * Room.tileSize) + 8

        return pixelPosition.x >= minX &&
            pixelPosition.x < maxX &&
            pixelPosition.y >= minY &&
            pixelPosition.y < maxY
    }

    public var exteriorSpawnPosition: Position {
        if let exteriorSpawnOverride {
            return exteriorSpawnOverride
        }

        return Position(
            x: (tileColumn * Room.tileSize) + ((tileWidth * Room.tileSize) / 2),
            y: max((tileRow * Room.tileSize) - 8, Room.tileSize + 8)
        )
    }
}

public struct Overworld: Codable, Equatable, Sendable {
    public static let width = 16
    public static let height = 8

    public var rooms: [ScreenCoordinate: Room]
    public var enemySpawns: [ScreenCoordinate: [Enemy]]
    public var caveEntrances: [ScreenCoordinate: [CaveEntrance]]
    public var roomFlags: [ScreenCoordinate: Int]
    public var cavePickups: [ScreenCoordinate: [CavePickup]]
    public var roomConnections: [ScreenCoordinate: Set<Direction>]

    public init(
        rooms: [ScreenCoordinate: Room],
        enemySpawns: [ScreenCoordinate: [Enemy]],
        caveEntrances: [ScreenCoordinate: [CaveEntrance]] = [:],
        roomFlags: [ScreenCoordinate: Int] = [:],
        cavePickups: [ScreenCoordinate: [CavePickup]] = [:],
        roomConnections: [ScreenCoordinate: Set<Direction>] = [:]
    ) {
        self.rooms = rooms
        self.enemySpawns = enemySpawns
        self.caveEntrances = caveEntrances
        self.roomFlags = roomFlags
        self.cavePickups = cavePickups
        self.roomConnections = roomConnections
    }

    public func room(at coordinate: ScreenCoordinate) -> Room? {
        rooms[coordinate]
    }

    public func hasRoom(at coordinate: ScreenCoordinate) -> Bool {
        room(at: coordinate) != nil
    }

    public func defaultEnemies(at coordinate: ScreenCoordinate) -> [Enemy] {
        enemySpawns[coordinate] ?? []
    }

    public func caveEntrance(at coordinate: ScreenCoordinate, pixelPosition: Position) -> CaveEntrance? {
        caveEntrances[coordinate]?.first(where: { $0.contains(pixelPosition: pixelPosition) })
    }

    public func flags(at coordinate: ScreenCoordinate) -> Int {
        roomFlags[coordinate] ?? 0
    }

    public func cavePickup(at coordinate: ScreenCoordinate, pixelPosition: Position) -> CavePickup? {
        cavePickups[coordinate]?.first(where: { $0.contains(pixelPosition: pixelPosition) })
    }

    public func linkedDestination(
        from coordinate: ScreenCoordinate,
        direction: Direction
    ) -> ScreenCoordinate? {
        guard hasRoom(at: coordinate) else {
            return nil
        }

        let destination = coordinate.moved(direction: direction)
        guard hasRoom(at: destination) else {
            return nil
        }

        if !roomConnections.isEmpty {
            guard roomConnections[coordinate]?.contains(direction) == true,
                  roomConnections[destination]?.contains(direction.opposite) == true
            else {
                return nil
            }
        }

        return destination
    }

    public func linkedDestinations(from coordinate: ScreenCoordinate) -> [Direction: ScreenCoordinate] {
        guard hasRoom(at: coordinate) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: Direction.allCases.compactMap { direction in
            guard let destination = linkedDestination(from: coordinate, direction: direction) else {
                return nil
            }

            return (direction, destination)
        })
    }

    public static func starterOverworld() -> Overworld {
        var rooms: [ScreenCoordinate: Room] = [:]
        var spawns: [ScreenCoordinate: [Enemy]] = [:]

        for row in 0..<height {
            for column in 0..<width {
                let coordinate = ScreenCoordinate(column: column, row: row)
                rooms[coordinate] = Room.starterRoom(coordinate: coordinate)

                if row % 2 == 0, column % 3 == 0 {
                    spawns[coordinate] = [
                        Enemy(kind: .octorok, position: Position(x: 96, y: 88)),
                        Enemy(kind: .tektite, position: Position(x: 176, y: 120))
                    ]
                }
            }
        }

        return Overworld(
            rooms: rooms,
            enemySpawns: spawns,
            caveEntrances: [:],
            roomFlags: [:],
            cavePickups: [:],
            roomConnections: adjacentConnections(for: rooms)
        )
    }
}

private extension Overworld {
    static func adjacentConnections(for rooms: [ScreenCoordinate: Room]) -> [ScreenCoordinate: Set<Direction>] {
        var connections: [ScreenCoordinate: Set<Direction>] = [:]

        for coordinate in rooms.keys {
            for direction in Direction.allCases {
                let destination = coordinate.moved(direction: direction)
                guard rooms[destination] != nil else {
                    continue
                }

                connections[coordinate, default: []].insert(direction)
            }
        }

        return connections
    }
}

public extension Direction {
    var opposite: Direction {
        switch self {
        case .up:
            return .down
        case .down:
            return .up
        case .left:
            return .right
        case .right:
            return .left
        }
    }
}
