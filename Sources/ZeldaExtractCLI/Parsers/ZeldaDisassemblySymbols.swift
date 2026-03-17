import Foundation

enum ZeldaDisassemblySymbols {
    static let overworldData: [ASMSelectionSpec] = [
        .init(
            exactLabels: [
                "RoomLayoutsOW",
                "RoomLayoutOWCave0",
                "RoomLayoutOWCave1",
                "RoomLayoutOWCave2",
                "ColumnHeapOW0", "ColumnHeapOW1", "ColumnHeapOW2", "ColumnHeapOW3",
                "ColumnHeapOW4", "ColumnHeapOW5", "ColumnHeapOW6", "ColumnHeapOW7",
                "ColumnHeapOW8", "ColumnHeapOW9", "ColumnHeapOWA", "ColumnHeapOWB",
                "ColumnHeapOWC", "ColumnHeapOWD", "ColumnHeapOWE", "ColumnHeapOWF"
            ],
            containsKeywords: ["overworld", "map", "column", "screen"],
            fileHints: ["z_05", "bank_05", "overworld"],
            maxBlocks: 24
        ),
        .init(
            exactLabels: ["OverworldScreenData", "OverworldRoomData", "RoomColumnData"],
            containsKeywords: ["overworld", "room", "column"],
            fileHints: ["map", "world"],
            maxBlocks: 8
        )
    ]

    static let overworldExitData: [ASMSelectionSpec] = [
        .init(
            exactLabels: [
                "OverworldPersonTextSelectors",
                "RoomLayoutsOWAddr",
                "ColumnDirectoryOW",
                "ColumnHeapOWAddr"
            ],
            containsKeywords: ["exit", "warp", "cave", "stairs"],
            fileHints: ["z_05", "z_01", "overworld"],
            maxBlocks: 4
        ),
        .init(
            exactLabels: ["CaveExitTable", "OverworldCaveTable"],
            containsKeywords: ["exit", "warp", "cave"],
            fileHints: ["overworld"],
            maxBlocks: 4
        )
    ]

    static let dungeonData: [ASMSelectionSpec] = [
        .init(
            exactLabels: [
                "RoomLayoutsUW",
                "ColumnHeapUW0", "ColumnHeapUW1", "ColumnHeapUW2", "ColumnHeapUW3", "ColumnHeapUW4",
                "ColumnHeapUW5", "ColumnHeapUW6", "ColumnHeapUW7", "ColumnHeapUW8", "ColumnHeapUW9",
                "ColumnHeapUWCellar",
                "LevelInfoUW1", "LevelInfoUW2", "LevelInfoUW3", "LevelInfoUW4", "LevelInfoUW5",
                "LevelInfoUW6", "LevelInfoUW7", "LevelInfoUW8", "LevelInfoUW9"
            ],
            containsKeywords: ["dungeon", "level", "room", "layout"],
            fileHints: ["z_05", "z_06", "underworld", "uw"],
            maxBlocks: 24
        ),
        .init(
            exactLabels: ["RoomAttrTable", "DoorTypeTable", "RoomEnemyTable"],
            containsKeywords: ["room", "door", "enemy", "dungeon"],
            fileHints: ["dungeon"],
            maxBlocks: 12
        )
    ]

    static let paletteData: [ASMSelectionSpec] = [
        .init(
            exactLabels: [
                "MenuPalettesTransferBuf",
                "LevelPaletteRow7TransferBuf",
                "TriforceRow0TransferBuf",
                "TitlePaletteTransferRecord",
                "StoryPaletteTransferRecord"
            ],
            containsKeywords: ["palette", "pal"],
            fileHints: ["z_06", "z_02", "palette"]
        ),
        .init(
            exactLabels: ["OverworldPalettes", "DungeonPalettes", "SpritePalettes"],
            containsKeywords: ["palette", "pal", "color"],
            fileHints: ["pal", "color"]
        )
    ]

    static let tileData: [ASMSelectionSpec] = [
        .init(
            exactLabels: [
                "CommonSpritePatterns",
                "CommonBackgroundPatterns",
                "CommonMiscPatterns",
                "PatternBlockOWBG",
                "PatternBlockOWSP",
                "PatternBlockUWBG",
                "PatternBlockUWSP",
                "DemoSpritePatterns",
                "DemoBackgroundPatterns"
            ],
            containsKeywords: ["chr", "tile", "pattern"],
            fileHints: ["z_02", "z_03", "z_01", "pattern"],
            maxBlocks: 12
        ),
        .init(
            exactLabels: ["OverworldTilePatterns", "DungeonTilePatterns", "MetatilePatternData"],
            containsKeywords: ["tile", "pattern", "metatile"],
            fileHints: ["tile", "pattern"],
            maxBlocks: 8
        )
    ]

    static let enemyData: [ASMSelectionSpec] = [
        .init(
            exactLabels: [
                "EnemyStatsData",
                "EnemyData",
                "EnemyHPTable",
                "EnemyDamageTable",
                "EnemySpeedTable",
                "ObjectTypeToHpPairs",
                "ObjectTypeToAttributes",
                "DropItemMonsterTypes0",
                "DropItemMonsterTypes1",
                "DropItemMonsterTypes2"
            ],
            containsKeywords: ["enemy", "monster", "stat", "hp"],
            fileHints: ["z_07", "z_04", "enemy"],
            maxBlocks: 6
        ),
        .init(
            exactLabels: ["EnemyHPTable", "EnemyDamageTable", "EnemySpeedTable"],
            containsKeywords: ["enemy", "damage", "speed", "hp"],
            fileHints: ["enemy", "combat"],
            maxBlocks: 6
        )
    ]

    static let itemData: [ASMSelectionSpec] = [
        .init(
            exactLabels: [
                "ItemPriceTable",
                "ItemCostTable",
                "MerchantPriceTable",
                "ItemData",
                "DropItemTable",
                "DropItemRates",
                "DropItemSetBaseOffsets",
                "ObjLists",
                "DemoLeftItemIds",
                "DemoRightItemIds"
            ],
            containsKeywords: ["item", "shop", "price"],
            fileHints: ["z_04", "z_05", "z_02", "item"],
            maxBlocks: 8
        ),
        .init(
            exactLabels: ["ItemCostTable", "MerchantPriceTable"],
            containsKeywords: ["item", "price", "merchant"],
            fileHints: ["shop"],
            maxBlocks: 4
        )
    ]

    static let damageData: [ASMSelectionSpec] = [
        .init(
            exactLabels: [
                "WeaponDamageTable",
                "SwordDamageTable",
                "ArrowDamageTable",
                "BombDamageTable",
                "ObjectTypeToAttributes",
                "ObjectTypeToHpPairs",
                "DropItemRates",
                "NoDropMonsterTypes"
            ],
            containsKeywords: ["damage", "weapon", "hurt"],
            fileHints: ["z_07", "z_04", "combat"],
            maxBlocks: 6
        ),
        .init(
            exactLabels: ["SwordDamageTable", "ArrowDamageTable", "BombDamageTable"],
            containsKeywords: ["damage", "sword", "arrow", "bomb"],
            fileHints: ["combat", "weapon"],
            maxBlocks: 6
        )
    ]

    static let linkSpriteData: [ASMSelectionSpec] = [
        .init(
            exactLabels: [
                "CommonSpritePatterns",
                "PatternBlockOWSP",
                "PatternBlockUWSP",
                "DemoSpritePatterns"
            ],
            containsKeywords: ["link", "player", "sprite"],
            fileHints: ["z_02", "z_03", "z_01", "sprite"],
            maxBlocks: 6
        ),
        .init(
            exactLabels: ["LinkWalkingFrames", "LinkAttackFrames"],
            containsKeywords: ["link", "frame", "sprite"],
            fileHints: ["sprite"],
            maxBlocks: 6
        )
    ]

    static let enemySpriteData: [ASMSelectionSpec] = [
        .init(
            exactLabels: [
                "PatternBlockOWSP",
                "PatternBlockUWSP358",
                "PatternBlockUWSP469",
                "PatternBlockUWSP127",
                "PatternBlockUWSPBoss1257",
                "PatternBlockUWSPBoss3468",
                "PatternBlockUWSPBoss9"
            ],
            containsKeywords: ["enemy", "monster", "sprite"],
            fileHints: ["z_03", "sprite", "pattern"],
            maxBlocks: 8
        ),
        .init(
            exactLabels: ["OctorokFrames", "TektiteFrames", "StalfosFrames"],
            containsKeywords: ["enemy", "frame", "sprite"],
            fileHints: ["sprite"],
            maxBlocks: 8
        )
    ]

    static let textData: [ASMSelectionSpec] = [
        .init(
            exactLabels: [
                "PersonText",
                "CreditsTextLines",
                "DemoTextFields",
                "PersonTextAddrs",
                "CreditsTextAddrsLo",
                "CreditsTextAddrsHi"
            ],
            containsKeywords: ["text", "dialog", "message", "hint"],
            fileHints: ["z_01", "z_02", "text"],
            maxBlocks: 24
        ),
        .init(
            exactLabels: ["CaveTextTable", "StoryTextData"],
            containsKeywords: ["text", "cave", "story"],
            fileHints: ["text"],
            maxBlocks: 24
        )
    ]

    static let audioData: [ASMSelectionSpec] = [
        .init(
            exactLabels: [
                "SongTable",
                "SongHeaderOverworld0",
                "SongHeaderUnderworld0",
                "SongHeaderGanon0",
                "SongScriptOverworld0",
                "SongScriptUnderworld0",
                "SongScriptGanon0",
                "SongScriptEnding0",
                "SongScriptItemTaken0"
            ],
            containsKeywords: ["music", "song", "sfx", "sound"],
            fileHints: ["z_00", "song", "audio"],
            maxBlocks: 16
        ),
        .init(
            exactLabels: ["OverworldThemeData", "DungeonThemeData", "BossThemeData"],
            containsKeywords: ["music", "theme", "song"],
            fileHints: ["sound", "music"],
            maxBlocks: 16
        )
    ]
}
