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
        XCTAssertEqual(state.phase, GamePhase.playing)
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
        XCTAssertEqual(state.phase, GamePhase.paused)

        _ = state.tick(input: InputState(start: true))
        XCTAssertEqual(state.phase, GamePhase.playing)
    }

    func testScrollTransitionCompletes() {
        let origin = ScreenCoordinate(column: 7, row: 3)
        let destination = ScreenCoordinate(column: 8, row: 3)
        let overworld = testOverworld(
            rooms: [
                origin: testRoom(coordinate: origin),
                destination: testRoom(coordinate: destination)
            ],
            enemySpawns: [
                origin: [Enemy(kind: .octorok, position: Position(x: 96, y: 88))],
                destination: [Enemy(kind: .octorok, position: Position(x: 112, y: 88))]
            ],
            roomConnections: [
                origin: [.right],
                destination: [.left]
            ]
        )

        var state = GameState(
            overworld: overworld,
            currentScreen: origin,
            link: Link(position: Position(x: Room.pixelWidth - 17, y: 88), facing: .right, hearts: 3, maxHearts: 3, speed: 2),
            inventory: .starter,
            phase: GamePhase.playing
        )

        let firstTickEvents = state.tick(input: InputState(direction: .right))
        XCTAssertTrue(firstTickEvents.isEmpty)
        XCTAssertEqual(state.phase, GamePhase.scrolling(ScrollTransition(direction: .right, origin: origin, destination: destination)))

        for _ in 0..<16 {
            _ = state.tick(input: InputState.idle)
        }

        XCTAssertEqual(state.phase, GamePhase.playing)
        XCTAssertEqual(state.currentScreen, destination)
    }

    func testScrollTransitionDoesNotStartWithOneWayRoomConnection() {
        let origin = ScreenCoordinate(column: 7, row: 3)
        let destination = ScreenCoordinate(column: 8, row: 3)
        let overworld = testOverworld(
            rooms: [
                origin: testRoom(coordinate: origin),
                destination: testRoom(coordinate: destination)
            ],
            roomConnections: [
                origin: [.right]
            ]
        )

        var state = GameState(
            overworld: overworld,
            currentScreen: origin,
            link: Link(position: Position(x: Room.pixelWidth - 17, y: 88), facing: .right, hearts: 3, maxHearts: 3, speed: 2),
            inventory: .starter,
            phase: GamePhase.playing
        )

        _ = state.tick(input: InputState(direction: .right))

        XCTAssertEqual(state.phase, GamePhase.playing)
        XCTAssertEqual(state.currentScreen, origin)
    }

    func testScrollTransitionDoesNotStartWithoutDestinationRoom() {
        let origin = ScreenCoordinate(column: 7, row: 3)
        let overworld = testOverworld(
            rooms: [
                origin: testRoom(coordinate: origin)
            ]
        )

        var state = GameState(
            overworld: overworld,
            currentScreen: origin,
            link: Link(position: Position(x: Room.pixelWidth - 17, y: 88), facing: .right, hearts: 3, maxHearts: 3, speed: 2),
            inventory: .starter,
            phase: GamePhase.playing
        )

        _ = state.tick(input: InputState(direction: .right))

        XCTAssertEqual(state.phase, GamePhase.playing)
        XCTAssertEqual(state.currentScreen, origin)
    }

    func testScrollTransitionDoesNotStartWithoutOriginRoomAtBoundary() {
        let origin = ScreenCoordinate(column: 0, row: 3)
        let eastNeighbor = ScreenCoordinate(column: 1, row: 3)
        let overworld = testOverworld(
            rooms: [
                eastNeighbor: testRoom(coordinate: eastNeighbor)
            ]
        )

        var state = GameState(
            overworld: overworld,
            currentScreen: origin,
            link: Link(position: Position(x: 17, y: 88), facing: .left, hearts: 3, maxHearts: 3, speed: 2),
            inventory: .starter,
            phase: GamePhase.playing
        )

        _ = state.tick(input: InputState(direction: .left))

        XCTAssertEqual(state.phase, GamePhase.playing)
        XCTAssertEqual(state.currentScreen, origin)
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
            phase: GamePhase.playing
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
            phase: GamePhase.playing
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
            phase: GamePhase.playing
        )

        let events = state.tick(input: InputState(direction: .down))

        XCTAssertEqual(events.last, .collectedItem(.woodenSword))
        XCTAssertEqual(state.inventory.swordLevel, 1)
        XCTAssertTrue(state.inventory.unlockedItems.contains(.woodenSword))
        XCTAssertEqual(state.currentRoomFlags & 0x10, 0x10)
    }

    func testPressingAStartsSwordSwingWhenSwordIsOwned() {
        let coordinate = ScreenCoordinate(column: 4, row: 4)
        let room = Room(
            coordinate: coordinate,
            collisionMask: Array(repeating: true, count: Room.columns * Room.rows)
        )
        let overworld = testOverworld(rooms: [coordinate: room])
        let inventory = Inventory(
            rupees: 0,
            bombs: 0,
            keys: 0,
            swordLevel: 1,
            unlockedItems: [.woodenSword]
        )

        var state = GameState(
            overworld: overworld,
            currentScreen: coordinate,
            link: Link(position: Position(x: 120, y: 120), facing: .up, hearts: 3, maxHearts: 3, speed: 2),
            inventory: inventory,
            phase: .playing
        )

        _ = state.tick(input: InputState(buttonA: true))

        XCTAssertTrue(state.isSwordSwinging)
        XCTAssertEqual(state.swordSwingDirection, .up)
        XCTAssertGreaterThan(state.swordSwingTicksRemaining, 0)
    }

    func testSwordDamagesEnemyOncePerSwingAndCanStrikeAgainAfterCooldown() {
        let coordinate = ScreenCoordinate(column: 4, row: 4)
        let room = Room(
            coordinate: coordinate,
            collisionMask: Array(repeating: false, count: Room.columns * Room.rows)
        )
        let overworld = testOverworld(rooms: [coordinate: room])
        let inventory = Inventory(
            rupees: 0,
            bombs: 0,
            keys: 0,
            swordLevel: 1,
            unlockedItems: [.woodenSword]
        )
        let enemy = Enemy(kind: .octorok, position: Position(x: 120, y: 104), hitPoints: 2, contactDamage: 1)

        var state = GameState(
            overworld: overworld,
            currentScreen: coordinate,
            link: Link(position: Position(x: 120, y: 120), facing: .up, hearts: 3, maxHearts: 3, speed: 2),
            enemies: [enemy],
            inventory: inventory,
            phase: .playing
        )

        _ = state.tick(input: InputState(buttonA: true))
        XCTAssertEqual(state.enemies.count, 1)
        XCTAssertEqual(state.enemies[0].hitPoints, 1)

        for _ in 0..<4 {
            _ = state.tick(input: .idle)
        }
        XCTAssertEqual(state.enemies.count, 1)
        XCTAssertEqual(state.enemies[0].hitPoints, 1)

        for _ in 0..<12 {
            _ = state.tick(input: .idle)
        }

        let events = state.tick(input: InputState(buttonA: true))
        XCTAssertTrue(events.contains(.enemyDefeated(.octorok)))
        XCTAssertTrue(state.enemies.isEmpty)
    }

    private func testOverworld(
        coordinate: ScreenCoordinate,
        caveEntrances: [ScreenCoordinate: [CaveEntrance]] = [:]
    ) -> Overworld {
        testOverworld(
            rooms: [coordinate: testRoom(coordinate: coordinate)],
            enemySpawns: [coordinate: [Enemy(kind: .octorok, position: Position(x: 96, y: 88))]],
            caveEntrances: caveEntrances
        )
    }

    private func testOverworld(
        rooms: [ScreenCoordinate: Room],
        enemySpawns: [ScreenCoordinate: [Enemy]] = [:],
        caveEntrances: [ScreenCoordinate: [CaveEntrance]] = [:],
        roomConnections: [ScreenCoordinate: Set<Direction>] = [:]
    ) -> Overworld {
        Overworld(
            rooms: rooms,
            enemySpawns: enemySpawns,
            caveEntrances: caveEntrances,
            roomConnections: roomConnections
        )
    }

    private func testRoom(coordinate: ScreenCoordinate) -> Room {
        Room(
            coordinate: coordinate,
            collisionMask: Array(repeating: true, count: Room.columns * Room.rows)
        )
    }
}
