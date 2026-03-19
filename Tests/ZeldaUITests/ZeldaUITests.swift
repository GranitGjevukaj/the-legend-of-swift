import XCTest
import ZeldaContent
import ZeldaCore
@testable import ZeldaUI

final class ZeldaUITests: XCTestCase {
    func testOverworldBuilderSkipsPricedCaveItems() {
        let coordinate = ScreenCoordinate(column: 0, row: 0)
        let screen = OverworldScreen(
            id: "OW_00_00",
            column: coordinate.column,
            row: coordinate.row,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: [],
            caveIndex: 0
        )

        let definition = CaveDefinition(
            index: 0,
            personType: 0x6A,
            textSelector: 0,
            caveFlags: 0,
            items: [
                CaveItem(slot: 0, itemId: 0x01, price: 0, flags: 0),
                CaveItem(slot: 1, itemId: 0x05, price: 20, flags: 0),
                CaveItem(slot: 2, itemId: nil, price: 0, flags: 0)
            ]
        )

        let data = OverworldData(
            width: 16,
            height: 8,
            screens: [screen],
            caveDefinitions: [definition]
        )

        let overworld = OverworldContentBuilder.build(from: data)
        let pickups = overworld.cavePickups[coordinate] ?? []

        XCTAssertEqual(pickups.count, 1)
        XCTAssertEqual(pickups.first?.kind, .woodenSword)
    }

    func testOverworldBuilderDoesNotInjectStarterEnemySpawns() {
        let coordinate = ScreenCoordinate(column: 7, row: 7)
        let screen = OverworldScreen(
            id: "OW_07_07",
            column: coordinate.column,
            row: coordinate.row,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: []
        )
        let data = OverworldData(width: 16, height: 8, screens: [screen])

        let overworld = OverworldContentBuilder.build(from: data)
        XCTAssertTrue(overworld.defaultEnemies(at: coordinate).isEmpty)
    }
}
