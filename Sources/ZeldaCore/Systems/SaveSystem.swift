import Foundation

public struct GameSaveSnapshot: Codable, Sendable {
    public var slot: Int
    public var currentScreen: ScreenCoordinate
    public var link: Link
    public var inventory: Inventory
    public var phase: String

    public init(slot: Int, currentScreen: ScreenCoordinate, link: Link, inventory: Inventory, phase: String) {
        self.slot = slot
        self.currentScreen = currentScreen
        self.link = link
        self.inventory = inventory
        self.phase = phase
    }

    public static func from(state: GameState) -> GameSaveSnapshot {
        GameSaveSnapshot(
            slot: state.slot,
            currentScreen: state.currentScreen,
            link: state.link,
            inventory: state.inventory,
            phase: String(describing: state.phase)
        )
    }
}

public struct SaveSystem: Sendable {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {}

    public func save(_ snapshot: GameSaveSnapshot, to url: URL) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    public func load(from url: URL) throws -> GameSaveSnapshot {
        let data = try Data(contentsOf: url)
        return try decoder.decode(GameSaveSnapshot.self, from: data)
    }

    public func restoreState(from snapshot: GameSaveSnapshot, overworld: Overworld = .starterOverworld()) -> GameState {
        GameState(
            slot: snapshot.slot,
            overworld: overworld,
            currentScreen: snapshot.currentScreen,
            link: snapshot.link,
            enemies: overworld.defaultEnemies(at: snapshot.currentScreen),
            projectiles: [],
            inventory: snapshot.inventory,
            phase: snapshot.phase == "paused" ? .paused : .playing
        )
    }
}
