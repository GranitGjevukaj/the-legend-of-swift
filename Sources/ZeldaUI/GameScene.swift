import Foundation
import CoreGraphics
import SpriteKit
import SwiftUI
import ZeldaContent
import ZeldaCore

@MainActor
public final class GameSession: ObservableObject {
    @Published public private(set) var state: GameState
    public let scene: GameScene
    public let hudPaletteBundle: PaletteBundle?
    public let hudCaveSpriteSheet: SpriteSheet?
    private let defaultStartScreen: ScreenCoordinate
    private let defaultStartLink: ZeldaCore.Link
    private let runtimeOverworld: Overworld
    private let loadedOverworld: OverworldData?
    private let textEntries: [String: String]

    public init() {
        let loader = ContentLoader.repositoryDefault()
        let loadedContent = try? loader.loadAll()
        loadedOverworld = loadedContent?.overworld
        textEntries = loadedContent?.text ?? [:]
        defaultStartScreen = Self.screenCoordinate(from: loadedContent?.overworld.startRoomId) ?? ScreenCoordinate(column: 7, row: 3)
        defaultStartLink = Self.linkSpawn(from: loadedContent?.overworld) ?? .spawnPoint
        runtimeOverworld = OverworldContentBuilder.build(from: loadedContent?.overworld)

        var bootState = GameState(overworld: runtimeOverworld)
        bootState.startNewGame(slot: 0, startScreen: defaultStartScreen, startLink: defaultStartLink)
        state = bootState

        let tileSet = try? loader.decode("tilesets/overworld.json") as TileSet
        hudPaletteBundle = loadedContent?.palettes
        hudCaveSpriteSheet = loadedContent?.caveSpriteSheet
        scene = GameScene(
            initialState: bootState,
            paletteBundle: loadedContent?.palettes,
            overworldData: loadedContent?.overworld,
            overworldTileSet: tileSet,
            linkSpriteSheet: loadedContent?.linkSpriteSheet,
            caveSpriteSheet: loadedContent?.caveSpriteSheet
        )
        scene.onStateChange = { [weak self] newState in
            self?.state = newState
        }
    }

    public var caveMessage: String? {
        CaveDialogueResolver.message(
            for: state,
            overworldData: loadedOverworld,
            textEntries: textEntries
        )
    }

    public func start(slot: Int) {
        var freshState = GameState(overworld: runtimeOverworld)
        freshState.startNewGame(slot: slot, startScreen: defaultStartScreen, startLink: defaultStartLink)
        state = freshState
        scene.replaceState(with: freshState)
    }

    public func send(_ input: InputState) {
        scene.enqueue(input: input)
    }

    private static func screenCoordinate(from roomId: Int?) -> ScreenCoordinate? {
        guard let roomId, (0..<(Overworld.width * Overworld.height)).contains(roomId) else {
            return nil
        }
        return ScreenCoordinate(column: roomId & 0x0F, row: roomId >> 4)
    }

    private static func linkSpawn(from overworld: OverworldData?) -> ZeldaCore.Link? {
        guard let startY = overworld?.startY else {
            return nil
        }

        return ZeldaCore.Link(
            position: Position(x: 0x78, y: startY),
            facing: .down,
            hearts: 3,
            maxHearts: 3,
            speed: 2
        )
    }
}

public final class GameScene: SKScene {
    private enum BackdropKey: Equatable {
        case overworld(ScreenCoordinate)
        case cave(ScreenCoordinate)
    }

    public var onStateChange: ((GameState) -> Void)?

    private var gameState: GameState
    private var gameLoop = GameLoop()
    private var pendingInput: InputState = .idle

    private let linkNode = SKSpriteNode()
    private let swordNode = SKSpriteNode()
    private let enemyLayer = SKNode()
    private let caveContentLayer = SKNode()
    private let backgroundNode = SKSpriteNode()
    private let linkPaletteBundle: PaletteBundle?
    private let overworldData: OverworldData?
    private let overworldTileSet: TileSet?
    private let linkSpriteSheet: SpriteSheet?
    private let caveSpriteSheet: SpriteSheet?
    private var linkTextureSet = LinkSpriteAtlas.TextureSet(walk: [:], attack: [:])
    private var backgroundTextureCache: [ScreenCoordinate: SKTexture] = [:]
    private var caveTextureCache: [String: SKTexture] = [:]
    private var swordTextureCache: [Int: SKTexture] = [:]
    private var lastLinkPosition: Position
    private var lastRenderedBackdrop: BackdropKey?
    private var lastRenderedRoomFlags: Int?
    private var linkWalkFrameIndex = 0
    private var hasExtractedAttackFrames = false

    public init(
        initialState: GameState,
        paletteBundle: PaletteBundle? = nil,
        overworldData: OverworldData? = nil,
        overworldTileSet: TileSet? = nil,
        linkSpriteSheet: SpriteSheet? = nil,
        caveSpriteSheet: SpriteSheet? = nil
    ) {
        gameState = initialState
        linkPaletteBundle = paletteBundle
        self.overworldData = overworldData
        self.overworldTileSet = overworldTileSet
        self.linkSpriteSheet = linkSpriteSheet
        self.caveSpriteSheet = caveSpriteSheet
        lastLinkPosition = initialState.link.position
        super.init(size: CGSize(width: Room.pixelWidth, height: Room.pixelHeight))
        scaleMode = .aspectFit
        anchorPoint = CGPoint(x: 0, y: 0)
        backgroundColor = .black
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMove(to _: SKView) {
        configureSceneNodes()
        syncNodes(with: gameState)
    }

    public func replaceState(with newState: GameState) {
        gameState = newState
        pendingInput = .idle
        lastLinkPosition = newState.link.position
        lastRenderedBackdrop = nil
        lastRenderedRoomFlags = nil
        linkWalkFrameIndex = 0
        syncNodes(with: gameState)
        onStateChange?(newState)
    }

    public func enqueue(input: InputState) {
        pendingInput = mergeInputs(current: pendingInput, incoming: input)
    }

    public override func update(_ currentTime: TimeInterval) {
        let ticks = gameLoop.ticksToSimulate(currentTime: currentTime)
        for _ in 0..<ticks {
            _ = gameState.tick(input: pendingInput)
            pendingInput = .idle
        }

        syncNodes(with: gameState)
        onStateChange?(gameState)
    }

    private func configureSceneNodes() {
        backgroundNode.anchorPoint = CGPoint(x: 0, y: 0)
        backgroundNode.position = CGPoint(x: 0, y: 0)
        backgroundNode.size = CGSize(width: Room.pixelWidth, height: Room.pixelHeight)
        backgroundNode.zPosition = -20
        addChild(backgroundNode)

        linkTextureSet = LinkSpriteAtlas.makeTextureSet(from: linkPaletteBundle, spriteSheet: linkSpriteSheet)
        hasExtractedAttackFrames = linkSpriteSheet?.frames.contains(where: { $0.id == "down_attack" }) == true
        linkNode.size = CGSize(width: 16, height: 16)
        linkNode.zPosition = 10
        linkNode.texture = currentLinkTexture(for: gameState)
        addChild(linkNode)

        swordNode.size = CGSize(width: 16, height: 16)
        swordNode.zPosition = 11
        swordNode.isHidden = true
        addChild(swordNode)

        caveContentLayer.zPosition = 4
        addChild(caveContentLayer)
        addChild(enemyLayer)
    }

    private func syncNodes(with state: GameState) {
        let backdrop = state.cave == nil ? BackdropKey.overworld(state.currentScreen) : BackdropKey.cave(state.currentScreen)
        if lastRenderedBackdrop != backdrop {
            renderBackground(for: state)
            lastRenderedBackdrop = backdrop
        }

        let roomFlags = state.currentRoomFlags
        if state.cave != nil {
            if lastRenderedBackdrop != backdrop || lastRenderedRoomFlags != roomFlags {
                renderCaveContents(for: state)
                lastRenderedRoomFlags = roomFlags
            }
        } else if lastRenderedRoomFlags != nil || caveContentLayer.children.isEmpty == false {
            renderCaveContents(for: state)
            lastRenderedRoomFlags = nil
        }

        let moved = state.link.position != lastLinkPosition
        if moved {
            linkWalkFrameIndex = (linkWalkFrameIndex + 1) % 2
        } else {
            linkWalkFrameIndex = 0
        }
        lastLinkPosition = state.link.position

        linkNode.texture = currentLinkTexture(for: state)
        linkNode.position = scenePoint(for: state.link.position)
        renderOverlaySword(for: state)

        enemyLayer.removeAllChildren()
        for enemy in state.enemies {
            let enemyNode = SKShapeNode(rectOf: CGSize(width: 12, height: 12), cornerRadius: 2)
            enemyNode.fillColor = .red
            enemyNode.strokeColor = .red
            enemyNode.position = scenePoint(for: enemy.position)
            enemyLayer.addChild(enemyNode)
        }
    }

    private func renderBackground(for state: GameState) {
        if state.cave != nil {
            let caveLayout = resolvedCaveLayout()
            let cacheKey = caveLayout?.id ?? "fallback"

            if let cached = caveTextureCache[cacheKey] {
                backgroundNode.texture = cached
                return
            }

            let texture = CaveScreenTextureBuilder.buildTexture(layout: caveLayout, tileSet: overworldTileSet)
            caveTextureCache[cacheKey] = texture
            backgroundNode.texture = texture
            return
        }

        let coordinate = state.currentScreen
        if let cached = backgroundTextureCache[coordinate] {
            backgroundNode.texture = cached
            return
        }

        guard
            let overworldData,
            let screen = overworldData.screens.first(where: { $0.column == coordinate.column && $0.row == coordinate.row })
        else {
            backgroundNode.texture = nil
            return
        }

        let texture = OverworldScreenTextureBuilder.buildTexture(
            screen: screen,
            tileSet: overworldTileSet,
            palettes: linkPaletteBundle
        )
        backgroundTextureCache[coordinate] = texture
        backgroundNode.texture = texture
    }

    private func resolvedCaveLayout() -> CaveLayout? {
        let layouts = overworldData?.caveLayouts ?? []
        return layouts.first(where: { $0.id == "cave_0" }) ?? layouts.first
    }

    private func renderCaveContents(for state: GameState) {
        caveContentLayer.removeAllChildren()
        guard state.cave != nil else {
            return
        }

        let screen = screenData(for: state)
        guard let caveIndex = screen?.caveIndex else {
            return
        }

        let definition = overworldData?.caveDefinitions?.first(where: { $0.index == caveIndex })
        for node in CaveContentNodeBuilder.buildNodes(
            definition: definition,
            roomFlags: state.currentRoomFlags,
            spriteSheet: caveSpriteSheet,
            paletteBundle: linkPaletteBundle
        ) {
            caveContentLayer.addChild(node)
        }
    }

    private func screenData(for state: GameState) -> OverworldScreen? {
        overworldData?.screens.first(where: {
            $0.column == state.currentScreen.column && $0.row == state.currentScreen.row
        })
    }

    private func currentLinkTexture(for state: GameState) -> SKTexture? {
        let directional: [SKTexture]
        let index: Int

        if state.isSwordSwinging, hasExtractedAttackFrames, let attackDirection = state.swordSwingDirection {
            directional = linkTextureSet.attack[attackDirection] ?? linkTextureSet.attack[.down] ?? []
            index = state.swordSwingFrame == 0 ? 0 : 1
        } else {
            directional = linkTextureSet.walk[state.link.facing] ?? linkTextureSet.walk[.down] ?? []
            index = linkWalkFrameIndex
        }

        guard !directional.isEmpty else {
            return nil
        }
        return directional[min(index, directional.count - 1)]
    }

    private func renderOverlaySword(for state: GameState) {
        guard
            state.isSwordSwinging,
            let direction = state.swordSwingDirection,
            let swordItemID = swordItemID(for: state.inventory.swordLevel)
        else {
            swordNode.isHidden = true
            return
        }

        swordNode.texture = swordTexture(for: swordItemID)
        let pose = swordPose(for: direction, frame: state.swordSwingFrame)
        swordNode.zRotation = pose.rotation
        swordNode.xScale = pose.xScale
        swordNode.yScale = pose.yScale
        swordNode.position = scenePoint(
            for: Position(
                x: state.link.position.x + pose.offsetX,
                y: state.link.position.y + pose.offsetY
            )
        )
        swordNode.isHidden = false
    }

    private func swordTexture(for itemID: Int) -> SKTexture {
        if let cached = swordTextureCache[itemID] {
            return cached
        }

        let texture = CaveContentNodeBuilder.itemTexture(
            for: itemID,
            spriteSheet: caveSpriteSheet,
            paletteBundle: linkPaletteBundle
        )
        swordTextureCache[itemID] = texture
        return texture
    }

    private func swordItemID(for swordLevel: Int) -> Int? {
        switch swordLevel {
        case 1:
            return 0x01
        case 2:
            return 0x02
        case 3:
            return 0x03
        default:
            return nil
        }
    }

    private struct SwordPose {
        let offsetX: Int
        let offsetY: Int
        let rotation: CGFloat
        let xScale: CGFloat
        let yScale: CGFloat
    }

    private func swordPose(for direction: Direction, frame: Int) -> SwordPose {
        switch direction {
        case .up:
            let poses = [
                SwordPose(offsetX: -6, offsetY: -8, rotation: 0, xScale: 1, yScale: 1),
                SwordPose(offsetX: -6, offsetY: -10, rotation: 0, xScale: 1, yScale: 1),
                SwordPose(offsetX: -6, offsetY: -9, rotation: 0, xScale: 1, yScale: 1)
            ]
            return poses[min(max(0, frame), poses.count - 1)]
        case .down:
            let poses = [
                SwordPose(offsetX: 2, offsetY: 6, rotation: 0, xScale: 1, yScale: -1),
                SwordPose(offsetX: 2, offsetY: 8, rotation: 0, xScale: 1, yScale: -1),
                SwordPose(offsetX: 2, offsetY: 7, rotation: 0, xScale: 1, yScale: -1)
            ]
            return poses[min(max(0, frame), poses.count - 1)]
        case .left:
            let poses = [
                SwordPose(offsetX: -6, offsetY: -2, rotation: .pi / 2, xScale: 1, yScale: 1),
                SwordPose(offsetX: -8, offsetY: -2, rotation: .pi / 2, xScale: 1, yScale: 1),
                SwordPose(offsetX: -7, offsetY: -2, rotation: .pi / 2, xScale: 1, yScale: 1)
            ]
            return poses[min(max(0, frame), poses.count - 1)]
        case .right:
            let poses = [
                SwordPose(offsetX: 6, offsetY: 2, rotation: -.pi / 2, xScale: 1, yScale: 1),
                SwordPose(offsetX: 8, offsetY: 2, rotation: -.pi / 2, xScale: 1, yScale: 1),
                SwordPose(offsetX: 7, offsetY: 2, rotation: -.pi / 2, xScale: 1, yScale: 1)
            ]
            return poses[min(max(0, frame), poses.count - 1)]
        }
    }

    private func mergeInputs(current: InputState, incoming: InputState) -> InputState {
        InputState(
            direction: incoming.direction ?? current.direction,
            buttonA: current.buttonA || incoming.buttonA,
            buttonB: current.buttonB || incoming.buttonB,
            start: current.start || incoming.start
        )
    }

    private func scenePoint(for position: Position) -> CGPoint {
        CGPoint(x: position.x, y: Room.pixelHeight - position.y)
    }
}
