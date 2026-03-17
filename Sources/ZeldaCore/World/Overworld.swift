import Foundation

public struct Overworld: Codable, Equatable, Sendable {
    public static let width = 16
    public static let height = 8

    public var rooms: [ScreenCoordinate: Room]
    public var enemySpawns: [ScreenCoordinate: [Enemy]]

    public init(rooms: [ScreenCoordinate: Room], enemySpawns: [ScreenCoordinate: [Enemy]]) {
        self.rooms = rooms
        self.enemySpawns = enemySpawns
    }

    public func room(at coordinate: ScreenCoordinate) -> Room? {
        rooms[coordinate]
    }

    public func defaultEnemies(at coordinate: ScreenCoordinate) -> [Enemy] {
        enemySpawns[coordinate] ?? []
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

        return Overworld(rooms: rooms, enemySpawns: spawns)
    }
}
