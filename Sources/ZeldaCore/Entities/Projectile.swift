import Foundation

public struct Projectile: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case swordBeam
        case arrow
        case boomerang
        case fire
        case magic
    }

    public var kind: Kind
    public var position: Position
    public var direction: Direction
    public var speed: Int

    public init(kind: Kind, position: Position, direction: Direction, speed: Int = 3) {
        self.kind = kind
        self.position = position
        self.direction = direction
        self.speed = speed
    }

    public var hitbox: Hitbox {
        Hitbox(x: position.x - 4, y: position.y - 4, width: 8, height: 8)
    }

    public mutating func advance() {
        position = position.moved(direction: direction, step: speed)
    }
}
