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

        scene = GameScene(initialState: bootState)
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

    private let linkNode = SKShapeNode(rectOf: CGSize(width: 12, height: 12), cornerRadius: 2)
    private let enemyLayer = SKNode()

    public init(initialState: GameState) {
        gameState = initialState
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
        let roomFrame = SKShapeNode(rectOf: CGSize(width: Room.pixelWidth - 2, height: Room.pixelHeight - 2), cornerRadius: 0)
        roomFrame.strokeColor = .gray
        roomFrame.lineWidth = 1
        roomFrame.position = CGPoint(x: CGFloat(Room.pixelWidth) / 2, y: CGFloat(Room.pixelHeight) / 2)
        addChild(roomFrame)

        linkNode.fillColor = .green
        linkNode.strokeColor = .green
        addChild(linkNode)

        addChild(enemyLayer)
    }

    private func syncNodes(with state: GameState) {
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

    private func mergeInputs(current: InputState, incoming: InputState) -> InputState {
        InputState(
            direction: incoming.direction ?? current.direction,
            buttonA: current.buttonA || incoming.buttonA,
            buttonB: current.buttonB || incoming.buttonB,
            start: current.start || incoming.start
        )
    }
}
