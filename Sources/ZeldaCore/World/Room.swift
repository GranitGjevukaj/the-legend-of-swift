import Foundation

public struct Room: Codable, Equatable, Sendable {
    public static let columns = 16
    public static let rows = 11
    public static let tileSize = 16

    public static var pixelWidth: Int { columns * tileSize }
    public static var pixelHeight: Int { rows * tileSize }

    public var coordinate: ScreenCoordinate
    public var collisionMask: [Bool]

    public init(coordinate: ScreenCoordinate, collisionMask: [Bool]) {
        self.coordinate = coordinate
        self.collisionMask = collisionMask
    }

    public func isWalkable(pixelPosition: Position) -> Bool {
        guard pixelPosition.x >= 0, pixelPosition.y >= 0 else { return false }
        let tileColumn = pixelPosition.x / Self.tileSize
        let tileRow = pixelPosition.y / Self.tileSize
        guard tileColumn < Self.columns, tileRow < Self.rows else { return false }
        let index = tileRow * Self.columns + tileColumn
        guard collisionMask.indices.contains(index) else { return false }
        return collisionMask[index]
    }

    public static func starterRoom(coordinate: ScreenCoordinate = ScreenCoordinate(column: 7, row: 3)) -> Room {
        var walkable = Array(repeating: true, count: columns * rows)

        for row in 0..<rows {
            for column in 0..<columns where row == 0 || row == rows - 1 || column == 0 || column == columns - 1 {
                walkable[row * columns + column] = false
            }
        }

        return Room(coordinate: coordinate, collisionMask: walkable)
    }
}
