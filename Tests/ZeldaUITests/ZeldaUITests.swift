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
        let originCoordinate = ScreenCoordinate(column: 2, row: 3)
        let downCoordinate = adjacentCoordinate(from: originCoordinate, direction: .down)
        let origin = OverworldScreen(
            id: "OW_03_02",
            column: originCoordinate.column,
            row: originCoordinate.row,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: ["south"]
        )
        let down = OverworldScreen(
            id: "OW_02_02",
            column: downCoordinate.column,
            row: downCoordinate.row,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: ["north"]
        )

        let data = OverworldData(width: 16, height: 8, screens: [origin, down])
        let overworld = OverworldContentBuilder.build(from: data)

        XCTAssertEqual(
            overworld.linkedDestination(from: originCoordinate, direction: .down),
            downCoordinate
        )
        XCTAssertEqual(
            overworld.linkedDestination(from: downCoordinate, direction: .up),
            originCoordinate
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

    func testOverworldBuilderLinksAdjacentRoomsWithoutExitMetadata() {
        let originCoordinate = ScreenCoordinate(column: 7, row: 6)
        let downCoordinate = adjacentCoordinate(from: originCoordinate, direction: .down)
        let origin = OverworldScreen(
            id: "OW_06_07",
            column: originCoordinate.column,
            row: originCoordinate.row,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: []
        )
        let down = OverworldScreen(
            id: "OW_05_07",
            column: downCoordinate.column,
            row: downCoordinate.row,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: []
        )

        let data = OverworldData(width: 16, height: 8, screens: [origin, down])
        let overworld = OverworldContentBuilder.build(from: data)

        XCTAssertEqual(
            overworld.linkedDestination(from: originCoordinate, direction: .down),
            downCoordinate
        )
        XCTAssertEqual(
            overworld.linkedDestination(from: downCoordinate, direction: .up),
            originCoordinate
        )
    }

    func testOverworldBuilderLinksAdjacentNorthEastSouthRooms() {
        let centerCoordinate = ScreenCoordinate(column: 5, row: 4)
        let northCoordinate = adjacentCoordinate(from: centerCoordinate, direction: .up)
        let eastCoordinate = adjacentCoordinate(from: centerCoordinate, direction: .right)
        let southCoordinate = adjacentCoordinate(from: centerCoordinate, direction: .down)

        let center = OverworldScreen(
            id: "OW_04_05",
            column: centerCoordinate.column,
            row: centerCoordinate.row,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: []
        )
        let north = OverworldScreen(
            id: "OW_05_05",
            column: northCoordinate.column,
            row: northCoordinate.row,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: []
        )
        let east = OverworldScreen(
            id: "OW_04_06",
            column: eastCoordinate.column,
            row: eastCoordinate.row,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: []
        )
        let south = OverworldScreen(
            id: "OW_03_05",
            column: southCoordinate.column,
            row: southCoordinate.row,
            metatileGrid: Array(repeating: 0, count: Room.columns * Room.rows),
            exits: []
        )

        let data = OverworldData(width: 16, height: 8, screens: [center, north, east, south])
        let overworld = OverworldContentBuilder.build(from: data)

        XCTAssertEqual(
            overworld.linkedDestination(from: centerCoordinate, direction: .up),
            northCoordinate
        )
        XCTAssertEqual(
            overworld.linkedDestination(from: centerCoordinate, direction: .right),
            eastCoordinate
        )
        XCTAssertEqual(
            overworld.linkedDestination(from: centerCoordinate, direction: .down),
            southCoordinate
        )
    }

    func testStartScreenTransitionsDownToNextOverworldScreen() throws {
        let loader = ContentLoader.repositoryDefault()
        let content = try loader.loadAll()
        let overworld = OverworldContentBuilder.build(from: content.overworld)
        let startRoomId = content.overworld.startRoomId ?? 0x77
        let startCoordinate = ScreenCoordinate(column: startRoomId & 0x0F, row: startRoomId >> 4)

        XCTAssertNil(overworld.linkedDestination(from: startCoordinate, direction: .up))
        XCTAssertEqual(
            overworld.linkedDestination(from: startCoordinate, direction: .down),
            adjacentCoordinate(from: startCoordinate, direction: .down)
        )
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

    private func adjacentCoordinate(from coordinate: ScreenCoordinate, direction: Direction) -> ScreenCoordinate {
        switch direction {
        case .up:
            return ScreenCoordinate(column: coordinate.column, row: coordinate.row + 1)
        case .down:
            return ScreenCoordinate(column: coordinate.column, row: coordinate.row - 1)
        case .left:
            return ScreenCoordinate(column: coordinate.column - 1, row: coordinate.row)
        case .right:
            return ScreenCoordinate(column: coordinate.column + 1, row: coordinate.row)
        }
    }
}
