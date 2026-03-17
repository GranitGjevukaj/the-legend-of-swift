import Foundation

public struct Enemy: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case octorok
        case tektite
        case leever
        case peahat
        case stalfos
        case gibdo
    }

    public var kind: Kind
    public var position: Position
    public var velocity: Position
    public var hitPoints: Int
    public var contactDamage: Int

    public init(kind: Kind, position: Position, velocity: Position = Position(x: 1, y: 0), hitPoints: Int = 2, contactDamage: Int = 1) {
        self.kind = kind
        self.position = position
        self.velocity = velocity
        self.hitPoints = hitPoints
        self.contactDamage = contactDamage
    }

    public var hitbox: Hitbox {
        Hitbox(x: position.x - 6, y: position.y - 6, width: 12, height: 12)
    }

    public mutating func tick(towards target: Position, in room: Room) {
        let xDirection = target.x == position.x ? 0 : (target.x > position.x ? 1 : -1)
        let yDirection = target.y == position.y ? 0 : (target.y > position.y ? 1 : -1)

        let horizontalCandidate = Position(x: position.x + xDirection, y: position.y)
        if room.isWalkable(pixelPosition: horizontalCandidate) {
            position = horizontalCandidate
        }

        let verticalCandidate = Position(x: position.x, y: position.y + yDirection)
        if room.isWalkable(pixelPosition: verticalCandidate) {
            position = verticalCandidate
        }
    }
}
