import XCTest
@testable import ZeldaCore

final class ZeldaCoreTests: XCTestCase {
    func testStartNewGameSetsSpawnState() {
        var state = GameState()

        state.startNewGame(slot: 2)

        XCTAssertEqual(state.currentScreen, ScreenCoordinate(column: 7, row: 3))
        XCTAssertEqual(state.link.position, Position(x: 120, y: 88))
        XCTAssertEqual(state.inventory.swordLevel, 1)
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
}
