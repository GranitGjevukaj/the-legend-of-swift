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

    public mutating func advance() {
        position = position.moved(direction: direction, step: speed)
    }
}
