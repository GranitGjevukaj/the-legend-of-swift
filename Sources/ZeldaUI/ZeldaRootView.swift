import SpriteKit
import SwiftUI
import ZeldaCore

public struct ZeldaRootView: View {
    public enum Stage {
        case title
        case fileSelect
        case game
    }

    @State private var stage: Stage = .title
    @StateObject private var session = GameSession()

    public init() {}

    public var body: some View {
        switch stage {
        case .title:
            TitleScreen {
                stage = .fileSelect
            }
        case .fileSelect:
            FileSelectView { slot in
                session.start(slot: slot)
                stage = .game
            }
        case .game:
            ZStack(alignment: .top) {
                SpriteView(scene: session.scene)
                    .ignoresSafeArea()
                    .onMoveCommand(perform: handleMove)
                    .onExitCommand {
                        session.send(InputState(start: true))
                    }

                HUDView(state: session.state)

                if session.state.phase == .paused {
                    PauseMenuView {
                        session.send(InputState(start: true))
                    }
                }
            }
            .background(Color.black)
        }
    }

    private func handleMove(_ direction: MoveCommandDirection) {
        let mapped: Direction?
        switch direction {
        case .up:
            mapped = .up
        case .down:
            mapped = .down
        case .left:
            mapped = .left
        case .right:
            mapped = .right
        @unknown default:
            mapped = nil
        }

        if let mapped {
            session.send(InputState(direction: mapped))
        }
    }
}
