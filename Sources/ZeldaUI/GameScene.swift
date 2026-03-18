import Foundation
import SpriteKit
import SwiftUI
import ZeldaContent
import ZeldaCore

@MainActor
public final class GameSession: ObservableObject {
    @Published public private(set) var state: GameState
    public let scene: GameScene

    public init() {
        var bootState = GameState()
        bootState.startNewGame(slot: 0)
        state = bootState

        let loader = ContentLoader.repositoryDefault()
        let loadedContent = try? loader.loadAll()
        let tileSet = try? loader.decode("tilesets/overworld.json") as TileSet
        scene = GameScene(
            initialState: bootState,
            paletteBundle: loadedContent?.palettes,
            overworldData: loadedContent?.overworld,
            overworldTileSet: tileSet
        )
        scene.onStateChange = { [weak self] newState in
            self?.state = newState
        }
    }

    public func start(slot: Int) {
        var freshState = GameState()
        freshState.startNewGame(slot: slot)
        state = freshState
        scene.replaceState(with: freshState)
    }

    public func send(_ input: InputState) {
        scene.enqueue(input: input)
    }
}

public final class GameScene: SKScene {
    public var onStateChange: ((GameState) -> Void)?

    private var gameState: GameState
    private var gameLoop = GameLoop()
    private var pendingInput: InputState = .idle

    private let linkNode = SKSpriteNode()
    private let enemyLayer = SKNode()
    private let backgroundNode = SKSpriteNode()
    private let linkPaletteBundle: PaletteBundle?
    private let overworldData: OverworldData?
    private let overworldTileSet: TileSet?
    private var linkTextures: [Direction: [SKTexture]] = [:]
    private var backgroundTextureCache: [ScreenCoordinate: SKTexture] = [:]
    private var lastLinkPosition: Position
    private var lastRenderedScreen: ScreenCoordinate?
    private var linkWalkFrameIndex = 0

    public init(
        initialState: GameState,
        paletteBundle: PaletteBundle? = nil,
        overworldData: OverworldData? = nil,
        overworldTileSet: TileSet? = nil
    ) {
        gameState = initialState
        linkPaletteBundle = paletteBundle
        self.overworldData = overworldData
        self.overworldTileSet = overworldTileSet
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
        lastRenderedScreen = nil
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

        let roomFrame = SKShapeNode(rectOf: CGSize(width: Room.pixelWidth - 2, height: Room.pixelHeight - 2), cornerRadius: 0)
        roomFrame.strokeColor = .gray
        roomFrame.lineWidth = 1
        roomFrame.position = CGPoint(x: CGFloat(Room.pixelWidth) / 2, y: CGFloat(Room.pixelHeight) / 2)
        roomFrame.zPosition = -10
        addChild(roomFrame)

        linkTextures = LinkSpriteAtlas.makeDirectionalTextures(from: linkPaletteBundle)
        linkNode.size = CGSize(width: 16, height: 16)
        linkNode.zPosition = 10
        linkNode.texture = currentLinkTexture(for: gameState.link.facing, walkFrame: 0)
        addChild(linkNode)

        addChild(enemyLayer)
    }

    private func syncNodes(with state: GameState) {
        if lastRenderedScreen != state.currentScreen {
            renderBackground(screen: state.currentScreen)
            lastRenderedScreen = state.currentScreen
        }

        let moved = state.link.position != lastLinkPosition
        if moved {
            linkWalkFrameIndex = (linkWalkFrameIndex + 1) % 2
        } else {
            linkWalkFrameIndex = 0
        }
        lastLinkPosition = state.link.position

        linkNode.texture = currentLinkTexture(for: state.link.facing, walkFrame: linkWalkFrameIndex)
        linkNode.position = CGPoint(x: state.link.position.x, y: state.link.position.y)

        enemyLayer.removeAllChildren()
        for enemy in state.enemies {
            let enemyNode = SKShapeNode(rectOf: CGSize(width: 12, height: 12), cornerRadius: 2)
            enemyNode.fillColor = .red
            enemyNode.strokeColor = .red
            enemyNode.position = CGPoint(x: enemy.position.x, y: enemy.position.y)
            enemyLayer.addChild(enemyNode)
        }
    }

    private func renderBackground(screen coordinate: ScreenCoordinate) {
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

    private func currentLinkTexture(for direction: Direction, walkFrame: Int) -> SKTexture? {
        let directional = linkTextures[direction] ?? linkTextures[.down] ?? []
        guard !directional.isEmpty else { return nil }
        let index = walkFrame % directional.count
        return directional[index]
    }

    private func mergeInputs(current: InputState, incoming: InputState) -> InputState {
        InputState(
            direction: incoming.direction ?? current.direction,
            buttonA: current.buttonA || incoming.buttonA,
            buttonB: current.buttonB || incoming.buttonB,
            start: current.start || incoming.start
        )
    }
}
