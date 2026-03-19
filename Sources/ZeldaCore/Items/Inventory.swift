import Foundation

public struct Inventory: Codable, Equatable, Sendable {
    public var rupees: Int
    public var bombs: Int
    public var keys: Int
    public var swordLevel: Int
    public var unlockedItems: Set<ItemDefinition.Kind>

    public init(rupees: Int, bombs: Int, keys: Int, swordLevel: Int, unlockedItems: Set<ItemDefinition.Kind>) {
        self.rupees = rupees
        self.bombs = bombs
        self.keys = keys
        self.swordLevel = swordLevel
        self.unlockedItems = unlockedItems
    }

    public static let empty = Inventory(rupees: 0, bombs: 0, keys: 0, swordLevel: 0, unlockedItems: [])

    public static let starter = Inventory(
        rupees: 0,
        bombs: 8,
        keys: 0,
        swordLevel: 0,
        unlockedItems: []
    )
}
