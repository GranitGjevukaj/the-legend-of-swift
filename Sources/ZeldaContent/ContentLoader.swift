import Foundation

public struct LoadedContent: Sendable {
    public var overworld: OverworldData
    public var dungeons: [DungeonData]
    public var palettes: PaletteBundle
    public var titleScreen: TitleScreenData?
    public var linkSpriteSheet: SpriteSheet?
    public var caveSpriteSheet: SpriteSheet?
    public var enemies: [EnemyDefinition]
    public var items: [ItemData]
    public var damageTable: [DamageRule]
    public var text: [String: String]
    public var audio: [String: String]

    public init(
        overworld: OverworldData,
        dungeons: [DungeonData],
        palettes: PaletteBundle,
        titleScreen: TitleScreenData? = nil,
        linkSpriteSheet: SpriteSheet? = nil,
        caveSpriteSheet: SpriteSheet? = nil,
        enemies: [EnemyDefinition],
        items: [ItemData],
        damageTable: [DamageRule],
        text: [String: String],
        audio: [String: String]
    ) {
        self.overworld = overworld
        self.dungeons = dungeons
        self.palettes = palettes
        self.titleScreen = titleScreen
        self.linkSpriteSheet = linkSpriteSheet
        self.caveSpriteSheet = caveSpriteSheet
        self.enemies = enemies
        self.items = items
        self.damageTable = damageTable
        self.text = text
        self.audio = audio
    }
}

public enum ContentLoaderError: Error, LocalizedError {
    case missingFile(String)

    public var errorDescription: String? {
        switch self {
        case let .missingFile(path):
            return "Missing content file at \(path)"
        }
    }
}

public struct ContentLoader: Sendable {
    public let baseURL: URL
    private let decoder: JSONDecoder

    public init(baseURL: URL) {
        self.baseURL = baseURL
        self.decoder = JSONDecoder()
    }

    public static func repositoryDefault(cwd: String = FileManager.default.currentDirectoryPath) -> ContentLoader {
        let fileManager = FileManager.default
        var cursor = URL(fileURLWithPath: cwd, isDirectory: true)

        while true {
            let packageManifest = cursor.appendingPathComponent("Package.swift")
            let repoContent = cursor.appendingPathComponent("Content/Zelda", isDirectory: true)
            if fileManager.fileExists(atPath: packageManifest.path()) &&
                fileManager.fileExists(atPath: repoContent.path())
            {
                return ContentLoader(baseURL: repoContent)
            }

            let parent = cursor.deletingLastPathComponent()
            if parent.path() == cursor.path() {
                break
            }
            cursor = parent
        }

        return ContentLoader(
            baseURL: URL(fileURLWithPath: cwd)
                .appendingPathComponent("Content/Zelda", isDirectory: true)
        )
    }

    public func loadAll() throws -> LoadedContent {
        let overworld: OverworldData = try decode("overworld.json")
        let palettes: PaletteBundle = try decode("palettes.json")
        let titleScreen: TitleScreenData? = try? decode("title_screen.json")
        let linkSpriteSheet = try loadSpriteSheet(prefix: "link")
        let caveSpriteSheet = try loadSpriteSheet(prefix: "cave")
        let enemies: [EnemyDefinition] = try decode("enemies.json")
        let items: [ItemData] = try decode("items.json")
        let damage: [DamageRule] = try decode("damage_table.json")
        let text: [String: String] = try decode("text.json")
        let audio: [String: String] = try decode("audio.json")

        var dungeons: [DungeonData] = []
        for level in 1...9 {
            let fileName = "dungeons/dungeon_\(level).json"
            if let dungeon: DungeonData = try? decode(fileName) {
                dungeons.append(dungeon)
            }
        }

        return LoadedContent(
            overworld: overworld,
            dungeons: dungeons,
            palettes: palettes,
            titleScreen: titleScreen,
            linkSpriteSheet: linkSpriteSheet,
            caveSpriteSheet: caveSpriteSheet,
            enemies: enemies,
            items: items,
            damageTable: damage,
            text: text,
            audio: audio
        )
    }

    public func decode<T: Decodable>(_ relativePath: String) throws -> T {
        let fileURL = baseURL.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            throw ContentLoaderError.missingFile(fileURL.path())
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(T.self, from: data)
    }

    private func loadSpriteSheet(prefix: String) throws -> SpriteSheet? {
        let spritesURL = baseURL.appendingPathComponent("sprites", isDirectory: true)
        guard FileManager.default.fileExists(atPath: spritesURL.path()) else {
            return nil
        }

        let candidates = try FileManager.default.contentsOfDirectory(
            at: spritesURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("\(prefix)_") && name.hasSuffix(".json")
        }
        .sorted { lhs, rhs in
            let lhsName = lhs.lastPathComponent
            let rhsName = rhs.lastPathComponent

            let lhsRank = spriteSheetPriority(for: lhsName, prefix: prefix)
            let rhsRank = spriteSheetPriority(for: rhsName, prefix: prefix)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }

            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }

            return lhsName < rhsName
        }

        guard let selected = candidates.first else {
            return nil
        }

        let data = try Data(contentsOf: selected)
        return try decoder.decode(SpriteSheet.self, from: data)
    }

    private func spriteSheetPriority(for fileName: String, prefix: String) -> Int {
        switch fileName {
        case "\(prefix)_src.json":
            return 0
        case "\(prefix)_asm.json":
            return 1
        case "\(prefix)_default.json":
            return 2
        default:
            return 3
        }
    }
}
