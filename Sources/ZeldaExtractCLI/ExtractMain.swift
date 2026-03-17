import Foundation
import ZeldaContent

public struct ExtractionConfig: Sendable {
    public var sourceURL: URL?
    public var outputURL: URL

    public init(sourceURL: URL?, outputURL: URL) {
        self.sourceURL = sourceURL
        self.outputURL = outputURL
    }
}

public struct ZeldaExtractor {
    private let config: ExtractionConfig
    private let fileManager = FileManager.default
    private let jsonWriter = JSONWriter()
    private let binaryWriter = BinaryWriter()

    public init(config: ExtractionConfig) {
        self.config = config
    }

    @discardableResult
    public func run() throws -> [URL] {
        try prepareDirectories()

        let overworld = OverworldParser().parse(from: config.sourceURL)
        let dungeons = DungeonParser().parse(from: config.sourceURL)
        let palettes = PaletteParser().parse(from: config.sourceURL)
        let enemies = EnemyDataParser().parse(from: config.sourceURL)
        let items = ItemTableParser().parse(from: config.sourceURL)
        let sprites = SpriteParser().parse(from: config.sourceURL)
        let text = TextParser().parseText(from: config.sourceURL)
        let audio = TextParser().parseAudio(from: config.sourceURL)
        let damageTable = DamageTableParser().parse(from: config.sourceURL)
        let tilesetArtifacts = TileSetParser().parse(from: config.sourceURL)

        var written: [URL] = []
        written.append(try jsonWriter.write(overworld, to: config.outputURL.appendingPathComponent("overworld.json")))
        written.append(try jsonWriter.write(palettes, to: config.outputURL.appendingPathComponent("palettes.json")))
        written.append(try jsonWriter.write(enemies, to: config.outputURL.appendingPathComponent("enemies.json")))
        written.append(try jsonWriter.write(items, to: config.outputURL.appendingPathComponent("items.json")))
        written.append(try jsonWriter.write(damageTable, to: config.outputURL.appendingPathComponent("damage_table.json")))
        written.append(try jsonWriter.write(text, to: config.outputURL.appendingPathComponent("text.json")))
        written.append(try jsonWriter.write(audio, to: config.outputURL.appendingPathComponent("audio.json")))

        for dungeon in dungeons {
            let url = config.outputURL
                .appendingPathComponent("dungeons", isDirectory: true)
                .appendingPathComponent("dungeon_\(dungeon.level).json")
            written.append(try jsonWriter.write(dungeon, to: url))
        }

        for sprite in sprites {
            let url = config.outputURL
                .appendingPathComponent("sprites", isDirectory: true)
                .appendingPathComponent("\(sprite.id).json")
            written.append(try jsonWriter.write(sprite, to: url))
        }

        written.append(try jsonWriter.write(tilesetArtifacts.tileSet, to: config.outputURL.appendingPathComponent("tilesets/overworld.json")))
        written.append(try binaryWriter.write(tilesetArtifacts.binary, to: config.outputURL.appendingPathComponent("tilesets/overworld.bin")))

        return written.sorted { $0.path() < $1.path() }
    }

    private func prepareDirectories() throws {
        try fileManager.createDirectory(at: config.outputURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: config.outputURL.appendingPathComponent("dungeons", isDirectory: true), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: config.outputURL.appendingPathComponent("sprites", isDirectory: true), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: config.outputURL.appendingPathComponent("tilesets", isDirectory: true), withIntermediateDirectories: true)
    }
}
