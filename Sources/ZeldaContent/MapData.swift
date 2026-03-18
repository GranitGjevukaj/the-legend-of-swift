import Foundation

public struct OverworldData: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var screens: [OverworldScreen]
    public var startRoomId: Int?
    public var startY: Int?

    public init(
        width: Int,
        height: Int,
        screens: [OverworldScreen],
        startRoomId: Int? = nil,
        startY: Int? = nil
    ) {
        self.width = width
        self.height = height
        self.screens = screens
        self.startRoomId = startRoomId
        self.startY = startY
    }
}

public struct OverworldScreen: Codable, Equatable, Sendable {
    public var id: String
    public var column: Int
    public var row: Int
    public var metatileGrid: [Int]
    public var exits: [String]
    public var paletteSelectorGrid: [Int]?
    public var roomFlags: Int?

    public init(
        id: String,
        column: Int,
        row: Int,
        metatileGrid: [Int],
        exits: [String],
        paletteSelectorGrid: [Int]? = nil,
        roomFlags: Int? = nil
    ) {
        self.id = id
        self.column = column
        self.row = row
        self.metatileGrid = metatileGrid
        self.exits = exits
        self.paletteSelectorGrid = paletteSelectorGrid
        self.roomFlags = roomFlags
    }
}

public struct DungeonData: Codable, Equatable, Sendable {
    public var level: Int
    public var rooms: [DungeonRoom]

    public init(level: Int, rooms: [DungeonRoom]) {
        self.level = level
        self.rooms = rooms
    }
}

public struct DungeonRoom: Codable, Equatable, Sendable {
    public var id: String
    public var doors: [String]
    public var enemies: [String]

    public init(id: String, doors: [String], enemies: [String]) {
        self.id = id
        self.doors = doors
        self.enemies = enemies
    }
}

public struct EnemyDefinition: Codable, Equatable, Sendable {
    public var id: String
    public var hitPoints: Int
    public var damage: Int
    public var speed: Int

    public init(id: String, hitPoints: Int, damage: Int, speed: Int) {
        self.id = id
        self.hitPoints = hitPoints
        self.damage = damage
        self.speed = speed
    }
}

public struct ItemData: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var shopPrice: Int?

    public init(id: String, name: String, shopPrice: Int?) {
        self.id = id
        self.name = name
        self.shopPrice = shopPrice
    }
}

public struct DamageRule: Codable, Equatable, Sendable {
    public var weapon: String
    public var enemy: String
    public var amount: Int

    public init(weapon: String, enemy: String, amount: Int) {
        self.weapon = weapon
        self.enemy = enemy
        self.amount = amount
    }
}
