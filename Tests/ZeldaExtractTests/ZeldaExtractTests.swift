import Foundation
import XCTest
@testable import ZeldaExtractCLI
@testable import ZeldaContent

final class ZeldaExtractTests: XCTestCase {
    func testExtractionIsDeterministic() throws {
        let fileManager = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let runA = base.appendingPathComponent("a", isDirectory: true)
        let runB = base.appendingPathComponent("b", isDirectory: true)

        try fileManager.createDirectory(at: runA, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: runB, withIntermediateDirectories: true)

        defer { try? fileManager.removeItem(at: base) }

        let artifactsA = try ZeldaExtractor(config: ExtractionConfig(sourceURL: nil, outputURL: runA)).run()
        let artifactsB = try ZeldaExtractor(config: ExtractionConfig(sourceURL: nil, outputURL: runB)).run()

        XCTAssertEqual(artifactsA.count, artifactsB.count)

        let relativeA = artifactsA.map { $0.lastPathComponent }.sorted()
        let relativeB = artifactsB.map { $0.lastPathComponent }.sorted()
        XCTAssertEqual(relativeA, relativeB)

        for fileName in relativeA {
            let dataA = try Data(contentsOf: runA.descendant(fileName: fileName))
            let dataB = try Data(contentsOf: runB.descendant(fileName: fileName))
            XCTAssertEqual(dataA, dataB, "Mismatch for \(fileName)")
        }
    }

    func testExtractionUsesASMSourceForOverworldAndPalettes() throws {
        let fileManager = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDir = base.appendingPathComponent("asm", isDirectory: true)
        let outputDir = base.appendingPathComponent("out", isDirectory: true)

        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: base) }

        let asm = """
        OverworldScreenData:
            .byte $01,$02,$03,$04,$05,$06,$07,$08
        OverworldExitTable:
            .byte %0001,%0100
        OverworldPalette:
            .byte $0F,$10,$11,$12
        DungeonPaletteLevel1:
            .byte $1A,$1B,$1C,$1D
        DungeonPaletteLevel9:
            .byte $2A,$2B,$2C,$2D
        LinkSpritePalette:
            .byte $3A,$3B,$3C,$3D
        EnemySpritePalette:
            .byte $05,$06,$07,$08
        DungeonRoomData:
            .byte $0F,$00,$01,$04,$02,$03,$08,$04,$05
        EnemyStatsData:
            .byte $02,$01,$01,$05,$02,$03,$06,$01,$02
        ItemPriceTable:
            .byte $14,$1E,$28,$32,$3C,$46,$50
        TilePatternData:
            .incbin "tiles.bin", $00, $40
        """

        let tileBytes = Data((0..<64).map { UInt8($0) })
        try tileBytes.write(to: sourceDir.appendingPathComponent("tiles.bin"))
        try asm.write(to: sourceDir.appendingPathComponent("tables.asm"), atomically: true, encoding: .utf8)
        _ = try ZeldaExtractor(config: ExtractionConfig(sourceURL: sourceDir, outputURL: outputDir)).run()

        let decoder = JSONDecoder()
        let overworldData = try Data(contentsOf: outputDir.appendingPathComponent("overworld.json"))
        let overworld = try decoder.decode(OverworldData.self, from: overworldData)

        XCTAssertEqual(overworld.width, 16)
        XCTAssertEqual(overworld.height, 8)
        XCTAssertEqual(overworld.screens.first?.metatileGrid.prefix(8), [1, 2, 3, 4, 5, 6, 7, 8])
        XCTAssertEqual(overworld.screens.first?.exits, ["north"])
        XCTAssertEqual(overworld.screens.dropFirst().first?.exits, ["west"])

        let paletteData = try Data(contentsOf: outputDir.appendingPathComponent("palettes.json"))
        let palettes = try decoder.decode(PaletteBundle.self, from: paletteData)

        XCTAssertEqual(palettes.areaPalettes["overworld"], [15, 16, 17, 18])
        XCTAssertEqual(palettes.areaPalettes["dungeon_1"], [26, 27, 28, 29])
        XCTAssertEqual(palettes.areaPalettes["dungeon_9"], [42, 43, 44, 45])
        XCTAssertEqual(palettes.spritePalettes["link"], [58, 59, 60, 61])
        XCTAssertEqual(palettes.spritePalettes["enemies"], [5, 6, 7, 8])

        let dungeonData = try Data(contentsOf: outputDir.appendingPathComponent("dungeons/dungeon_1.json"))
        let dungeon = try decoder.decode(DungeonData.self, from: dungeonData)
        XCTAssertEqual(dungeon.rooms.first?.doors, ["north", "south", "west", "east"])
        XCTAssertEqual(dungeon.rooms.first?.enemies, ["stalfos", "gibdo"])
        XCTAssertEqual(dungeon.rooms.dropFirst().first?.doors, ["west"])

        let enemyData = try Data(contentsOf: outputDir.appendingPathComponent("enemies.json"))
        let enemies = try decoder.decode([EnemyDefinition].self, from: enemyData)
        XCTAssertEqual(enemies.first?.id, "octorok")
        XCTAssertEqual(enemies.first?.hitPoints, 3)
        XCTAssertEqual(enemies.first?.damage, 2)
        XCTAssertEqual(enemies.first?.speed, 2)

        let itemData = try Data(contentsOf: outputDir.appendingPathComponent("items.json"))
        let items = try decoder.decode([ItemData].self, from: itemData)
        XCTAssertEqual(items.first(where: { $0.id == "bomb" })?.shopPrice, 100)
        XCTAssertEqual(items.first(where: { $0.id == "boomerang" })?.shopPrice, 120)

        let tileBin = try Data(contentsOf: outputDir.appendingPathComponent("tilesets/overworld.bin"))
        XCTAssertEqual(Array(tileBin.prefix(16)), Array(0..<16).map(UInt8.init))

        let tileJSONData = try Data(contentsOf: outputDir.appendingPathComponent("tilesets/overworld.json"))
        let tileSet = try decoder.decode(TileSet.self, from: tileJSONData)
        XCTAssertEqual(tileSet.tiles.first?.pixels.prefix(8), [0, 1, 2, 3, 4, 5, 6, 7])
    }

    func testExactLabelPriorityBeatsGenericKeywordMatches() throws {
        let fileManager = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDir = base.appendingPathComponent("asm", isDirectory: true)
        let outputDir = base.appendingPathComponent("out", isDirectory: true)

        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: base) }

        let asm = """
        EnemyData:
            .byte $7F,$7F,$7F,$7F,$7F,$7F
        EnemyStatsData:
            .byte $01,$00,$00,$02,$01,$01
        ItemData:
            .byte $7F,$7F,$7F,$7F,$7F,$7F,$7F
        ItemPriceTable:
            .byte $01,$02,$03,$04,$05,$06,$07
        """

        try asm.write(to: sourceDir.appendingPathComponent("priority.asm"), atomically: true, encoding: .utf8)
        _ = try ZeldaExtractor(config: ExtractionConfig(sourceURL: sourceDir, outputURL: outputDir)).run()

        let decoder = JSONDecoder()

        let enemyData = try Data(contentsOf: outputDir.appendingPathComponent("enemies.json"))
        let enemies = try decoder.decode([EnemyDefinition].self, from: enemyData)
        XCTAssertEqual(enemies.first?.hitPoints, 2)
        XCTAssertEqual(enemies.first?.damage, 1)
        XCTAssertEqual(enemies.first?.speed, 1)

        let itemData = try Data(contentsOf: outputDir.appendingPathComponent("items.json"))
        let items = try decoder.decode([ItemData].self, from: itemData)
        XCTAssertEqual(items.first(where: { $0.id == "bomb" })?.shopPrice, 10)
    }
}

private extension URL {
    func descendant(fileName: String) -> URL {
        if fileName.hasPrefix("dungeon_") {
            return appendingPathComponent("dungeons/\(fileName)")
        }
        if fileName.hasSuffix(".bin") || fileName == "overworld.json" {
            if fileName == "overworld.bin" {
                return appendingPathComponent("tilesets/\(fileName)")
            }
        }

        for path in [
            fileName,
            "dungeons/\(fileName)",
            "sprites/\(fileName)",
            "tilesets/\(fileName)"
        ] {
            let candidate = appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: candidate.path()) {
                return candidate
            }
        }

        return appendingPathComponent(fileName)
    }
}
