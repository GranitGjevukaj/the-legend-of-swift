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
    private let projectileLayer = SKNode()
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
    private var projectileTextureCache: [String: SKTexture] = [:]
    private var lastLinkPosition: Position
    private var lastRenderedBackdrop: BackdropKey?
    private var lastRenderedRoomFlags: Int?
    private var linkWalkFrameIndex = 0
    private var hasExtractedAttackFrames = false
    private var projectileAnimationCounter = 0
    private static let boomerangFrameCycle = [0, 1, 2, 1, 0, 1, 2, 1]
    private static let boomerangBaseSpriteAttrCycle = [0x00, 0x00, 0x00, 0x40, 0x40, 0xC0, 0x80, 0x80]

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
            projectileAnimationCounter = (projectileAnimationCounter + 1) & 0xFF
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
        projectileLayer.zPosition = 9
        addChild(projectileLayer)
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
        renderProjectiles(for: state)

        enemyLayer.removeAllChildren()
        for enemy in state.enemies {
            let enemyNode = SKShapeNode(rectOf: CGSize(width: 12, height: 12), cornerRadius: 2)
            enemyNode.fillColor = .red
            enemyNode.strokeColor = .red
            enemyNode.position = scenePoint(for: enemy.position)
            enemyLayer.addChild(enemyNode)
        }
    }

    private func renderProjectiles(for state: GameState) {
        projectileLayer.removeAllChildren()
        for projectile in state.projectiles {
            if let texture = projectileTexture(for: projectile) {
                let node = SKSpriteNode(texture: texture)
                node.size = CGSize(width: 16, height: 16)
                let orientation = projectileOrientationScale(for: projectile)
                node.xScale = orientation.x
                node.yScale = orientation.y
                node.zRotation = projectileRotation(for: projectile)
                let offset = projectileSpriteOffset(for: projectile)
                node.position = scenePoint(
                    for: Position(
                        x: projectile.position.x + offset.x,
                        y: projectile.position.y + offset.y
                    )
                )
                projectileLayer.addChild(node)
                continue
            }

            let node = SKShapeNode(rectOf: CGSize(width: 8, height: 8), cornerRadius: 1)
            node.fillColor = SKColor(red: 0.72, green: 0.96, blue: 1.0, alpha: 1.0)
            node.strokeColor = SKColor(red: 0.12, green: 0.45, blue: 0.78, alpha: 1.0)
            node.position = scenePoint(for: projectile.position)
            projectileLayer.addChild(node)
        }
    }

    private func projectileTexture(for projectile: Projectile) -> SKTexture? {
        guard let frameID = projectileFrameID(for: projectile) else {
            return nil
        }

        let phase = projectilePalettePhase(for: projectile)
        let cacheKey = "\(frameID)-\(projectile.kind.rawValue)-\(phase)"
        if let cached = projectileTextureCache[cacheKey] {
            return cached
        }

        let pixels: [UInt8]?
        if frameID == "standing_fire" {
            pixels = framePixels(id: frameID, in: caveSpriteSheet)
        } else {
            pixels = framePixels(id: frameID, in: linkSpriteSheet)
        }

        guard let pixels else {
            return nil
        }

        let palette = projectilePalette(for: projectile.kind, flashPhase: phase)
        let texture = texture(from: pixels, width: 16, height: 16, palette: palette)
        projectileTextureCache[cacheKey] = texture
        return texture
    }

    private func projectileFrameID(for projectile: Projectile) -> String? {
        switch projectile.kind {
        case .swordBeam:
            return "sword_beam_vertical"
        case .arrow:
            return "arrow_vertical"
        case .boomerang:
            let cycleIndex = boomerangCycleIndex()
            let frame = Self.boomerangFrameCycle[cycleIndex]
            return "boomerang_\(frame)"
        case .fire:
            return "standing_fire"
        case .magic:
            return "magic_beam_vertical"
        }
    }

    private func projectileOrientationScale(for projectile: Projectile) -> (x: CGFloat, y: CGFloat) {
        switch projectile.kind {
        case .swordBeam, .arrow, .magic:
            let yScale: CGFloat = projectile.direction == .down ? -1 : 1
            return (1, yScale)
        case .boomerang:
            let attributes = Self.boomerangBaseSpriteAttrCycle[boomerangCycleIndex()]
            let xScale: CGFloat = (attributes & 0x40) == 0 ? 1 : -1
            let yScale: CGFloat = (attributes & 0x80) == 0 ? 1 : -1
            return (xScale, yScale)
        case .fire:
            return (1, 1)
        }
    }

    private func projectileRotation(for projectile: Projectile) -> CGFloat {
        switch projectile.kind {
        case .swordBeam, .arrow, .magic:
            switch projectile.direction {
            case .left:
                return .pi / 2
            case .right:
                return -.pi / 2
            case .up, .down:
                return 0
            }
        case .boomerang, .fire:
            return 0
        }
    }

    private func boomerangCycleIndex() -> Int {
        let ticksPerFrame = 2
        return (projectileAnimationCounter / ticksPerFrame) % Self.boomerangFrameCycle.count
    }

    private func projectilePalettePhase(for projectile: Projectile) -> Int {
        switch projectile.kind {
        case .swordBeam, .magic:
            return projectileAnimationCounter & 0x03
        default:
            return 0
        }
    }

    private func projectileSpriteOffset(for projectile: Projectile) -> (x: Int, y: Int) {
        switch projectile.kind {
        case .swordBeam, .magic:
            return (0, 0)
        case .arrow:
            return (-4, 0)
        case .boomerang, .fire:
            return (0, 0)
        }
    }

    private func framePixels(id: String, in spriteSheet: SpriteSheet?) -> [UInt8]? {
        guard
            let spriteSheet,
            let frame = spriteSheet.frames.first(where: { $0.id == id }),
            frame.width == 16,
            frame.height == 16,
            let pixels = frame.pixels,
            pixels.count == 16 * 16
        else {
            return nil
        }
        return pixels
    }

    private struct RGBA {
        let r: UInt8
        let g: UInt8
        let b: UInt8
        let a: UInt8
    }

    private func projectilePalette(for kind: Projectile.Kind, flashPhase: Int) -> [RGBA] {
        switch kind {
        case .fire:
            return [
                RGBA(r: 0, g: 0, b: 0, a: 0),
                nesColor(index: 6, fallback: RGBA(r: 168, g: 16, b: 0, a: 255)),
                nesColor(index: 38, fallback: RGBA(r: 248, g: 120, b: 88, a: 255)),
                nesColor(index: 40, fallback: RGBA(r: 248, g: 184, b: 0, a: 255))
            ]
        default:
            let fallbackRows = [
                [15, 48, 0, 18],
                [15, 22, 39, 54],
                [15, 26, 55, 18],
                [15, 23, 55, 18]
            ]
            let rows = linkPaletteBundle?.areaPaletteSets?["overworld"] ?? fallbackRows
            let row = rows[min(max(0, flashPhase), rows.count - 1)]
            let slot1 = row.indices.contains(1) ? row[1] : 48
            let slot2 = row.indices.contains(2) ? row[2] : 39
            let slot3 = row.indices.contains(3) ? row[3] : 18
            return [
                RGBA(r: 0, g: 0, b: 0, a: 0),
                nesColor(index: slot1, fallback: RGBA(r: 252, g: 252, b: 252, a: 255)),
                nesColor(index: slot2, fallback: RGBA(r: 104, g: 136, b: 252, a: 255)),
                nesColor(index: slot3, fallback: RGBA(r: 228, g: 92, b: 16, a: 255))
            ]
        }
    }

    private func nesColor(index: Int, fallback: RGBA) -> RGBA {
        guard
            let bundle = linkPaletteBundle,
            bundle.nesColors.indices.contains(index),
            let parsed = parseHexColor(bundle.nesColors[index])
        else {
            return fallback
        }
        return parsed
    }

    private func parseHexColor(_ hex: String) -> RGBA? {
        guard hex.count == 7, hex.hasPrefix("#"),
              let value = Int(String(hex.dropFirst()), radix: 16)
        else {
            return nil
        }

        return RGBA(
            r: UInt8((value >> 16) & 0xFF),
            g: UInt8((value >> 8) & 0xFF),
            b: UInt8(value & 0xFF),
            a: 255
        )
    }

    private func texture(from pixels: [UInt8], width: Int, height: Int, palette: [RGBA]) -> SKTexture {
        var rgba = Array(repeating: UInt8(0), count: width * height * 4)
        for (index, slot) in pixels.enumerated() {
            let color = palette.indices.contains(Int(slot)) ? palette[Int(slot)] : palette[0]
            let output = index * 4
            rgba[output] = color.r
            rgba[output + 1] = color.g
            rgba[output + 2] = color.b
            rgba[output + 3] = color.a
        }

        let data = Data(rgba) as CFData
        guard
            let provider = CGDataProvider(data: data),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            return SKTexture()
        }

        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
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
