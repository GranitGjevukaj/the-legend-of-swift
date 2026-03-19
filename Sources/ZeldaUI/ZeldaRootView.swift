import AppKit
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
            ZStack {
                VStack(spacing: 0) {
                    HUDView(state: session.state)

                    ZStack(alignment: .bottom) {
                        GameSpriteContainer(
                            scene: session.scene,
                            onInput: { input in
                                session.send(input)
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if let caveMessage = session.caveMessage {
                            CaveDialogueBanner(text: caveMessage)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if session.state.phase == .paused {
                    PauseMenuView {
                        session.send(InputState(start: true))
                    }
                }

                GameKeyboardShortcuts(
                    onInput: { input in
                        session.send(input)
                    }
                )
            }
            .background(Color.black)
        }
    }
}

private struct CaveDialogueBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.78))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
    }
}

private struct GameKeyboardShortcuts: View {
    let onInput: (InputState) -> Void

    var body: some View {
        VStack(spacing: 0) {
            shortcutButton(.up, shortcut: .upArrow)
            shortcutButton(.down, shortcut: .downArrow)
            shortcutButton(.left, shortcut: .leftArrow)
            shortcutButton(.right, shortcut: .rightArrow)
            Button("") { onInput(InputState(start: true)) }
                .keyboardShortcut(.return, modifiers: [])
            Button("") { onInput(InputState(start: true)) }
                .keyboardShortcut(.escape, modifiers: [])
            Button("") { onInput(InputState(start: true)) }
                .keyboardShortcut(.space, modifiers: [])
            Button("") { onInput(InputState(buttonA: true)) }
                .keyboardShortcut("z", modifiers: [])
            Button("") { onInput(InputState(buttonB: true)) }
                .keyboardShortcut("x", modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0.001)
        .accessibilityHidden(true)
    }

    private func shortcutButton(_ direction: Direction, shortcut: KeyEquivalent) -> some View {
        Button("") {
            onInput(InputState(direction: direction))
        }
        .keyboardShortcut(shortcut, modifiers: [])
    }
}

private struct GameSpriteContainer: NSViewRepresentable {
    let scene: SKScene
    let onInput: (InputState) -> Void

    func makeNSView(context: Context) -> InputHostingSKView {
        let view = InputHostingSKView()
        view.onInput = onInput
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        view.presentScene(scene)
        view.ensureFocus()
        return view
    }

    func updateNSView(_ nsView: InputHostingSKView, context: Context) {
        nsView.onInput = onInput
        if nsView.scene !== scene {
            nsView.presentScene(scene)
        }
        nsView.ensureFocus()
    }
}

private final class InputHostingSKView: SKView {
    var onInput: ((InputState) -> Void)?
    private var keyMonitor: Any?
    private var heldDirection: Direction?
    private var repeatTimer: Timer?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startMonitoringIfNeeded()
        ensureFocus()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            stopMonitoring()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func keyDown(with event: NSEvent) {
        if handleKeyDown(event) {
            return
        }

        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if handleKeyUp(event) {
            return
        }

        super.keyUp(with: event)
    }

    func ensureFocus() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            if window.firstResponder !== self {
                window.makeFirstResponder(self)
            }
        }
    }

    private func startMonitoringIfNeeded() {
        guard keyMonitor == nil else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }

            switch event.type {
            case .keyDown:
                return self.handleKeyDown(event) ? nil : event
            case .keyUp:
                return self.handleKeyUp(event) ? nil : event
            default:
                return event
            }
        }
    }

    private func stopMonitoring() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        stopRepeatingDirection()
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 123:
            setHeldDirection(.left)
            return true
        case 124:
            setHeldDirection(.right)
            return true
        case 125:
            setHeldDirection(.down)
            return true
        case 126:
            setHeldDirection(.up)
            return true
        case 36, 49, 53:
            onInput?(InputState(start: true))
            return true
        case 6:
            onInput?(InputState(buttonA: true))
            return true
        case 7:
            onInput?(InputState(buttonB: true))
            return true
        default:
            return false
        }
    }

    private func handleKeyUp(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 123 where heldDirection == .left:
            stopRepeatingDirection()
            return true
        case 124 where heldDirection == .right:
            stopRepeatingDirection()
            return true
        case 125 where heldDirection == .down:
            stopRepeatingDirection()
            return true
        case 126 where heldDirection == .up:
            stopRepeatingDirection()
            return true
        default:
            return false
        }
    }

    private func setHeldDirection(_ direction: Direction) {
        heldDirection = direction
        onInput?(InputState(direction: direction))
        guard repeatTimer == nil else { return }

        repeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let heldDirection = self.heldDirection else { return }
                self.onInput?(InputState(direction: heldDirection))
            }
        }
    }

    private func stopRepeatingDirection() {
        heldDirection = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
