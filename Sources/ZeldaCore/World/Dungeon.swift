import Foundation

public struct Dungeon: Codable, Equatable, Sendable {
    public var level: Int
    public var rooms: [Int: Room]

    public init(level: Int, rooms: [Int: Room]) {
        self.level = level
        self.rooms = rooms
    }
}
