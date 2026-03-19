import XCTest
@testable import ZeldaCore

final class ZeldaCoreTests: XCTestCase {
    func testStartNewGameSetsSpawnState() {
        var state = GameState()

        state.startNewGame(slot: 2)

        XCTAssertEqual(state.currentScreen, ScreenCoordinate(column: 7, row: 3))
        XCTAssertEqual(state.link.position, Position(x: 120, y: 88))
        XCTAssertEqual(state.inventory.swordLevel, 0)
        XCTAssertFalse(state.inventory.unlockedItems.contains(.woodenSword))
        XCTAssertEqual(state.phase, .playing)
    }

    func testMovementUpdatesLinkPosition() {
        var state = GameState()
        state.startNewGame(slot: 0)

        let start = state.link.position
        _ = state.tick(input: InputState(direction: .right))

        XCTAssertGreaterThan(state.link.position.x, start.x)
        XCTAssertEqual(state.link.facing, .right)
    }

    func testPauseAndResume() {
        var state = GameState()
        state.startNewGame(slot: 0)

        _ = state.tick(input: InputState(start: true))
        XCTAssertEqual(state.phase, .paused)

        _ = state.tick(input: InputState(start: true))
        XCTAssertEqual(state.phase, .playing)
    }

    func testScrollTransitionCompletes() {
        var state = GameState()
        state.startNewGame(slot: 0)

        var safety = 0
        while state.phase == .playing && safety < 200 {
            _ = state.tick(input: InputState(direction: .right))
            safety += 1
        }

        guard case .scrolling = state.phase else {
            XCTFail("Expected to enter scrolling state")
            return
        }

        for _ in 0..<20 {
            _ = state.tick(input: .idle)
        }

        XCTAssertEqual(state.phase, .playing)
        XCTAssertEqual(state.currentScreen, ScreenCoordinate(column: 8, row: 3))
    }

    func testWalkingIntoCaveEntranceEntersCave() {
        let coordinate = ScreenCoordinate(column: 7, row: 7)
        let entrance = CaveEntrance(tileColumn: 7, tileRow: 1)
        let overworld = testOverworld(
            coordinate: coordinate,
            caveEntrances: [coordinate: [entrance]]
        )

        var state = GameState(
            overworld: overworld,
            currentScreen: coordinate,
            link: Link(position: Position(x: 120, y: 34), facing: .up, hearts: 3, maxHearts: 3, speed: 2),
            inventory: .starter,
            phase: .playing
        )

        let events = state.tick(input: InputState(direction: .up))

        XCTAssertEqual(events.last, .enteredCave(coordinate))
        XCTAssertEqual(state.cave, CaveState(parentScreen: coordinate, entrance: entrance))
        XCTAssertEqual(state.link.position, CaveState.spawnPosition)
        XCTAssertEqual(state.link.facing, .up)
        XCTAssertTrue(state.enemies.isEmpty)
    }

    func testWalkingOutOfCaveReturnsToOverworldEntrance() {
        let coordinate = ScreenCoordinate(column: 7, row: 7)
        let entrance = CaveEntrance(tileColumn: 7, tileRow: 1)
        let cave = CaveState(parentScreen: coordinate, entrance: entrance)
        let overworld = testOverworld(
            coordinate: coordinate,
            caveEntrances: [coordinate: [entrance]]
        )

        var state = GameState(
            overworld: overworld,
            currentScreen: coordinate,
            cave: cave,
            link: Link(position: Position(x: 120, y: Room.pixelHeight - 26), facing: .down, hearts: 3, maxHearts: 3, speed: 2),
            inventory: .starter,
            phase: .playing
        )

        let events = state.tick(input: InputState(direction: .down))

        XCTAssertEqual(events.last, .exitedCave(coordinate))
        XCTAssertNil(state.cave)
        XCTAssertEqual(state.link.position, entrance.exteriorSpawnPosition)
        XCTAssertEqual(state.link.facing, .down)
    }

    func testCollectingCaveSwordUpdatesInventoryAndRoomFlags() {
        let coordinate = ScreenCoordinate(column: 7, row: 7)
        let entrance = CaveEntrance(tileColumn: 7, tileRow: 8)
        let cave = CaveState(parentScreen: coordinate, entrance: entrance)
        var overworld = testOverworld(
            coordinate: coordinate,
            caveEntrances: [coordinate: [entrance]]
        )
        overworld.roomFlags[coordinate] = 0
        overworld.cavePickups[coordinate] = [CavePickup(slot: 1, kind: .woodenSword)]

        var state = GameState(
            overworld: overworld,
            currentScreen: coordinate,
            cave: cave,
            link: Link(position: Position(x: 120, y: 86), facing: .down, hearts: 3, maxHearts: 3, speed: 2),
            inventory: .starter,
            phase: .playing
        )

        let events = state.tick(input: InputState(direction: .down))

        XCTAssertEqual(events.last, .collectedItem(.woodenSword))
        XCTAssertEqual(state.inventory.swordLevel, 1)
        XCTAssertTrue(state.inventory.unlockedItems.contains(.woodenSword))
        XCTAssertEqual(state.currentRoomFlags & 0x10, 0x10)
    }

    private func testOverworld(
        coordinate: ScreenCoordinate,
        caveEntrances: [ScreenCoordinate: [CaveEntrance]] = [:]
    ) -> Overworld {
        let room = Room(
            coordinate: coordinate,
            collisionMask: Array(repeating: true, count: Room.columns * Room.rows)
        )

        return Overworld(
            rooms: [coordinate: room],
            enemySpawns: [coordinate: [Enemy(kind: .octorok, position: Position(x: 96, y: 88))]],
            caveEntrances: caveEntrances
        )
    }
}
