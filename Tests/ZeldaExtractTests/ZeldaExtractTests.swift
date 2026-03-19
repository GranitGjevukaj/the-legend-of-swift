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
            .byte $1A,$FF,$2A,$FF,$3A,$FF,$4A,$FF,$5A,$FF,$6A,$FF,$7A,$FF,$8A,$FF
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
            .byte $39,$00,$01,$04,$02,$03,$08,$04,$05
        EnemyStatsData:
            .byte $02,$01,$01,$05,$02,$03,$06,$01,$02
        ItemPriceTable:
            .byte $14,$1E,$28,$32,$3C,$46,$50
        WeaponDamageTable:
            .byte $03,$04,$05,$06,$07,$00,$01,$02
        LinkSpriteFrames:
            .byte $10,$11,$12,$13,$14,$15,$16,$17
        EnemySpriteFrames:
            .byte $20,$21,$22,$23,$24,$25,$26,$27
        DialogueText:
            .byte "HELLO HYRULE",0
        SongOverworld:
            .byte $20,$01,$02
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
        XCTAssertNil(overworld.caveLayouts)
        XCTAssertNil(overworld.caveDefinitions)

        let paletteData = try Data(contentsOf: outputDir.appendingPathComponent("palettes.json"))
        let palettes = try decoder.decode(PaletteBundle.self, from: paletteData)

        XCTAssertEqual(palettes.areaPalettes["overworld"], [15, 16, 17, 18])
        XCTAssertEqual(palettes.areaPalettes["dungeon_1"], [26, 27, 28, 29])
        XCTAssertEqual(palettes.areaPalettes["dungeon_9"], [42, 43, 44, 45])
        XCTAssertEqual(palettes.spritePalettes["link"], [58, 59, 60, 61])
        XCTAssertEqual(palettes.spritePalettes["enemies"], [5, 6, 7, 8])

        let dungeonData = try Data(contentsOf: outputDir.appendingPathComponent("dungeons/dungeon_1.json"))
        let dungeon = try decoder.decode(DungeonData.self, from: dungeonData)
        XCTAssertEqual(dungeon.rooms.first?.doors, ["north:locked", "south:bombable", "west:shutter", "east:open"])
        XCTAssertEqual(dungeon.rooms.first?.enemies, ["stalfos", "gibdo"])
        XCTAssertEqual(dungeon.rooms.dropFirst().first?.doors, ["north:open", "south:locked", "west:open", "east:open"])

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

        let damageData = try Data(contentsOf: outputDir.appendingPathComponent("damage_table.json"))
        let damageRules = try decoder.decode([DamageRule].self, from: damageData)
        XCTAssertEqual(damageRules.first?.weapon, "wooden_sword")
        XCTAssertEqual(damageRules.first?.enemy, "octorok")
        XCTAssertEqual(damageRules.first?.amount, 3)

        let textData = try Data(contentsOf: outputDir.appendingPathComponent("text.json"))
        let textEntries = try decoder.decode([String: String].self, from: textData)
        XCTAssertEqual(textEntries["dialoguetext"], "HELLO HYRULE")

        let audioData = try Data(contentsOf: outputDir.appendingPathComponent("audio.json"))
        let audioEntries = try decoder.decode([String: String].self, from: audioData)
        XCTAssertEqual(audioEntries["songoverworld"], "tempo:112;instrument:triangle;length:long")

        let linkSpriteData = try Data(contentsOf: outputDir.appendingPathComponent("sprites/link_asm.json"))
        let linkSheet = try decoder.decode(SpriteSheet.self, from: linkSpriteData)
        XCTAssertEqual(linkSheet.frames.count, 4)

        let tileBin = try Data(contentsOf: outputDir.appendingPathComponent("tilesets/overworld.bin"))
        XCTAssertEqual(Array(tileBin.prefix(16)), Array(0..<16).map(UInt8.init))

        let tileJSONData = try Data(contentsOf: outputDir.appendingPathComponent("tilesets/overworld.json"))
        let tileSet = try decoder.decode(TileSet.self, from: tileJSONData)
        XCTAssertEqual(tileSet.tiles.count, 256)
        XCTAssertEqual(tileSet.tiles.first?.pixels.count, 64)
        XCTAssertTrue(tileSet.tiles.first?.pixels.allSatisfy { (0...3).contains(Int($0)) } ?? false)
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

    func testFileHintPriorityForMatchingLabels() throws {
        let fileManager = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDir = base.appendingPathComponent("asm", isDirectory: true)
        let outputDir = base.appendingPathComponent("out", isDirectory: true)

        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: base) }

        let noisy = """
        EnemyStatsData:
            .byte $7F,$7F,$7F,$7F,$7F,$7F
        ItemPriceTable:
            .byte $7F,$7F,$7F,$7F,$7F,$7F,$7F
        """

        let banked = """
        EnemyStatsData:
            .byte $01,$00,$00,$02,$01,$01
        ItemPriceTable:
            .byte $01,$02,$03,$04,$05,$06,$07
        """

        try noisy.write(to: sourceDir.appendingPathComponent("misc.asm"), atomically: true, encoding: .utf8)
        try banked.write(to: sourceDir.appendingPathComponent("bank4_enemy.asm"), atomically: true, encoding: .utf8)
        try banked.write(to: sourceDir.appendingPathComponent("bank5_items.asm"), atomically: true, encoding: .utf8)

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

    func testGoldenTextCharacterTableDecoding() throws {
        let fileManager = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDir = base.appendingPathComponent("asm", isDirectory: true)
        let outputDir = base.appendingPathComponent("out", isDirectory: true)

        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: base) }

        let asm = """
        DialogueText:
            .byte $08,$05,$0C,$0C,$0F,$2F,$08,$19,$12,$15,$0C,$05,$2C,$00
        """

        try asm.write(to: sourceDir.appendingPathComponent("text_table.asm"), atomically: true, encoding: .utf8)
        _ = try ZeldaExtractor(config: ExtractionConfig(sourceURL: sourceDir, outputURL: outputDir)).run()

        let data = try Data(contentsOf: outputDir.appendingPathComponent("text.json"))
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        XCTAssertEqual(decoded["dialoguetext"], "HELLO HYRULE!")
    }

    func testRealDisassemblyGoldenExtractionIfAvailable() throws {
        let sourceDir = try realDisassemblySourceURL()
        let fileManager = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let outputDir = base.appendingPathComponent("out", isDirectory: true)
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: base) }

        let artifacts = try ZeldaExtractor(config: ExtractionConfig(sourceURL: sourceDir, outputURL: outputDir)).run()
        XCTAssertEqual(artifacts.count, 20)

        let decoder = JSONDecoder()

        let overworldData = try Data(contentsOf: outputDir.appendingPathComponent("overworld.json"))
        let overworld = try decoder.decode(OverworldData.self, from: overworldData)
        XCTAssertEqual(overworld.width, 16)
        XCTAssertEqual(overworld.height, 8)
        XCTAssertEqual(Array(overworld.screens[0].metatileGrid.prefix(8)), [27, 27, 27, 27, 27, 27, 27, 27])
        XCTAssertEqual(overworld.caveLayouts?.map(\.id), ["cave_0", "cave_1", "cave_2"])
        XCTAssertEqual(overworld.caveLayouts?.first?.metatileGrid.count, 16 * 11)
        let startScreen = overworld.screens.first(where: { $0.column == 7 && $0.row == 7 })
        XCTAssertEqual(startScreen?.caveIndex, 0)
        XCTAssertEqual(startScreen?.undergroundExitX, 0x40)
        XCTAssertEqual(startScreen?.undergroundExitY, 0x4D)
        XCTAssertEqual(Array(startScreen?.metatileGrid[16..<32] ?? []), [0x1B, 0x1B, 0x1B, 0x1B, 0x0C, 0x1B, 0x35, 0x0E, 0x0E, 0x1B, 0x1B, 0x1B, 0x1B, 0x1B, 0x1B, 0x1B])
        XCTAssertEqual(Array(startScreen?.metatileGrid[64..<80] ?? []), [0x1B, 0x35, 0x0E, 0x0E, 0x0E, 0x0E, 0x0E, 0x0E, 0x0E, 0x34, 0x1B, 0x1B, 0x1B, 0x1B, 0x1B, 0x1B])
        XCTAssertEqual(overworld.caveDefinitions?.first?.personType, 0x6A)
        XCTAssertEqual(overworld.caveDefinitions?.first?.items.map(\.itemId), [nil, 1, nil])

        let paletteData = try Data(contentsOf: outputDir.appendingPathComponent("palettes.json"))
        let palettes = try decoder.decode(PaletteBundle.self, from: paletteData)
        XCTAssertEqual(palettes.areaPalettes["overworld"], [15, 48, 0, 18])
        XCTAssertEqual(palettes.areaPalettes["dungeon_1"], [48, 0, 18, 15])
        XCTAssertEqual(palettes.spritePalettes["link"], [15, 41, 39, 23])
        XCTAssertEqual(palettes.spritePalettes["enemies"], [15, 2, 34, 48])

        let dungeonData = try Data(contentsOf: outputDir.appendingPathComponent("dungeons/dungeon_1.json"))
        let dungeon = try decoder.decode(DungeonData.self, from: dungeonData)
        XCTAssertEqual(dungeon.rooms.first?.doors, ["north:open", "south:open", "west:open", "east:open"])
        XCTAssertEqual(dungeon.rooms.first?.enemies, ["stalfos", "stalfos"])

        let enemyData = try Data(contentsOf: outputDir.appendingPathComponent("enemies.json"))
        let enemies = try decoder.decode([EnemyDefinition].self, from: enemyData)
        XCTAssertEqual(enemies.first?.id, "octorok")
        XCTAssertEqual(enemies.first?.hitPoints, 7)
        XCTAssertEqual(enemies.first?.damage, 4)
        XCTAssertEqual(enemies.first?.speed, 2)

        let itemData = try Data(contentsOf: outputDir.appendingPathComponent("items.json"))
        let items = try decoder.decode([ItemData].self, from: itemData)
        XCTAssertEqual(items.first(where: { $0.id == "bomb" })?.shopPrice, 48)
        XCTAssertEqual(items.first(where: { $0.id == "boomerang" })?.shopPrice, 70)

        let audioData = try Data(contentsOf: outputDir.appendingPathComponent("audio.json"))
        let audio = try decoder.decode([String: String].self, from: audioData)
        XCTAssertEqual(audio["songtable"], "tempo:85;instrument:triangle;length:long")
        XCTAssertEqual(audio["songheaderoverworld0"], "tempo:96;instrument:pulse;length:medium")

        let textData = try Data(contentsOf: outputDir.appendingPathComponent("text.json"))
        let text = try decoder.decode([String: String].self, from: textData)
        XCTAssertEqual(Set(text.keys), ["creditstextlines", "demotextfields", "persontext"])
        XCTAssertFalse(text["persontext"]?.isEmpty ?? true)

        let linkSpriteData = try Data(contentsOf: outputDir.appendingPathComponent("sprites/link_src.json"))
        let linkSheet = try decoder.decode(SpriteSheet.self, from: linkSpriteData)
        XCTAssertEqual(linkSheet.frames.map(\.id), ["horizontal_0", "horizontal_1", "down", "up"])
        XCTAssertTrue(linkSheet.frames.allSatisfy { $0.pixels?.count == 256 })
    }

    func testIncbinResolvesFromSiblingBinDirectory() throws {
        let fileManager = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDir = base.appendingPathComponent("src", isDirectory: true)
        let binDir = base.appendingPathComponent("bin/dat", isDirectory: true)
        let outputDir = base.appendingPathComponent("out", isDirectory: true)

        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: binDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: base) }

        // bins.xml marks sourceDir as a disassembly-style source root.
        try "<Binaries/>".write(to: sourceDir.appendingPathComponent("bins.xml"), atomically: true, encoding: .utf8)

        let incbinData = Data((0..<32).map(UInt8.init))
        try incbinData.write(to: binDir.appendingPathComponent("PatternBlockOWBG.dat"))

        let asm = """
        PatternBlockOWBG:
            .incbin "dat/PatternBlockOWBG.dat"
        """

        try asm.write(to: sourceDir.appendingPathComponent("tiles.asm"), atomically: true, encoding: .utf8)
        _ = try ZeldaExtractor(config: ExtractionConfig(sourceURL: sourceDir, outputURL: outputDir)).run()

        let tileBin = try Data(contentsOf: outputDir.appendingPathComponent("tilesets/overworld.bin"))
        XCTAssertEqual(Array(tileBin.prefix(32)), Array(incbinData))
    }

    private func realDisassemblySourceURL() throws -> URL {
        let env = ProcessInfo.processInfo.environment
        let override = env["ZELDA1_DISASSEMBLY_SRC"] ?? env["ZELDA_DISASSEMBLY_SRC"]
        let path = override ?? "/tmp/zelda1-disassembly/src"
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw XCTSkip("Real disassembly source not found at \(path). Set ZELDA1_DISASSEMBLY_SRC to enable this golden test.")
        }
        return URL(fileURLWithPath: path, isDirectory: true)
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
