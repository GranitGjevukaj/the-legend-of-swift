import XCTest
import ZeldaContent
import ZeldaCore
@testable import ZeldaUI

final class ZeldaUITests: XCTestCase {
    @MainActor
    func testHUDSwordKindMappingMatchesInventoryLevel() {
        XCTAssertNil(HUDView.swordKind(for: 0))
        XCTAssertEqual(HUDView.swordKind(for: 1), .woodenSword)
        XCTAssertEqual(HUDView.swordKind(for: 2), .whiteSword)
        XCTAssertEqual(HUDView.swordKind(for: 3), .magicSword)
    }

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

    func testOverworldBuilderMapsCardinalExitNamesToLinkedRooms() {
        let top = OverworldScreen(
            id: "OW_02_03",
            column: 2,
            row: 3,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: ["south"]
        )
        let bottom = OverworldScreen(
            id: "OW_02_04",
            column: 2,
            row: 4,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: ["north"]
        )

        let data = OverworldData(width: 16, height: 8, screens: [top, bottom])
        let overworld = OverworldContentBuilder.build(from: data)

        let topCoordinate = ScreenCoordinate(column: 2, row: 3)
        let bottomCoordinate = ScreenCoordinate(column: 2, row: 4)

        XCTAssertEqual(
            overworld.linkedDestination(from: topCoordinate, direction: .down),
            bottomCoordinate
        )
        XCTAssertEqual(
            overworld.linkedDestination(from: bottomCoordinate, direction: .up),
            topCoordinate
        )
    }

    func testOverworldBuilderDoesNotWrapRoomLinksAcrossMapEdges() {
        let leftEdge = OverworldScreen(
            id: "OW_00_03",
            column: 0,
            row: 3,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: ["west"]
        )
        let rightEdge = OverworldScreen(
            id: "OW_15_03",
            column: 15,
            row: 3,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: ["east"]
        )

        let data = OverworldData(width: 16, height: 8, screens: [leftEdge, rightEdge])
        let overworld = OverworldContentBuilder.build(from: data)
        let leftCoordinate = ScreenCoordinate(column: 0, row: 3)
        let rightCoordinate = ScreenCoordinate(column: 15, row: 3)

        XCTAssertNil(overworld.linkedDestination(from: leftCoordinate, direction: .left))
        XCTAssertNil(overworld.linkedDestination(from: rightCoordinate, direction: .right))
    }

    @MainActor
    func testSwordCaveRendersOldManSwordAndFlames() {
        let definition = CaveDefinition(
            index: 0,
            personType: 0x6A,
            textSelector: 0,
            caveFlags: 0x04,
            items: [
                CaveItem(slot: 1, itemId: 0x01, price: 0, flags: 0)
            ]
        )

        let nodes = CaveContentNodeBuilder.buildNodes(definition: definition, roomFlags: 0)
        let names = Set(nodes.compactMap(\.name))

        XCTAssertTrue(names.contains("cave-person"))
        XCTAssertTrue(names.contains("cave-item-1"))
        XCTAssertTrue(names.contains("cave-flame-0"))
        XCTAssertTrue(names.contains("cave-flame-1"))
    }
}
