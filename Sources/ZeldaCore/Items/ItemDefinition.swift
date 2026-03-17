import Foundation

public struct ItemDefinition: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Hashable, Sendable {
        case woodenSword
        case whiteSword
        case magicSword
        case boomerang
        case bow
        case bomb
        case candle
        case raft
        case ladder
        case powerBracelet
    }

    public var kind: Kind
    public var displayName: String
    public var price: Int?

    public init(kind: Kind, displayName: String, price: Int?) {
        self.kind = kind
        self.displayName = displayName
        self.price = price
    }
}
