import Foundation

public struct Link: Codable, Equatable, Sendable {
    public var position: Position
    public var facing: Direction
    public var hearts: Int
    public var maxHearts: Int
    public var speed: Int

    public init(position: Position, facing: Direction, hearts: Int, maxHearts: Int, speed: Int) {
        self.position = position
        self.facing = facing
        self.hearts = hearts
        self.maxHearts = maxHearts
        self.speed = speed
    }

    public static let spawnPoint = Link(position: Position(x: 120, y: 88), facing: .down, hearts: 3, maxHearts: 3, speed: 2)

    public var hitbox: Hitbox {
        Hitbox(x: position.x - 6, y: position.y - 6, width: 12, height: 12)
    }

    public var swordHitbox: Hitbox {
        swordHitbox(facing: facing)
    }

    public func swordHitbox(facing direction: Direction) -> Hitbox {
        switch direction {
        case .up:
            return Hitbox(x: position.x - 4, y: position.y - 22, width: 8, height: 16)
        case .down:
            return Hitbox(x: position.x - 4, y: position.y + 6, width: 8, height: 16)
        case .left:
            return Hitbox(x: position.x - 22, y: position.y - 4, width: 16, height: 8)
        case .right:
            return Hitbox(x: position.x + 6, y: position.y - 4, width: 16, height: 8)
        }
    }
}
