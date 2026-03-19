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

                    ZStack(alignment: .top) {
                        GameSpriteContainer(
                            scene: session.scene,
                            onInput: { input in
                                session.send(input)
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if let caveMessage = session.caveMessage {
                            CaveDialogueBanner(text: caveMessage)
                                .padding(.top, 64)
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
        let lines = Self.wrap(text.uppercased(), maxColumns: 20)

        NESPixelText(lines: lines, pixelSize: 5, color: Color(red: 0.95, green: 0.95, blue: 0.95))
            .padding(.horizontal, 6)
            .padding(.vertical, 0)
            .frame(width: 520, alignment: .center)
    }

    private static func wrap(_ text: String, maxColumns: Int) -> [String] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else {
            return [""]
        }

        var lines: [String] = []
        var current = ""

        for word in words {
            if current.isEmpty {
                current = word
                continue
            }

            if current.count + 1 + word.count <= maxColumns {
                current += " \(word)"
                continue
            }

            lines.append(current)
            current = word
        }

        if !current.isEmpty {
            lines.append(current)
        }

        return lines
    }
}

private struct NESPixelText: View {
    let lines: [String]
    let pixelSize: CGFloat
    let color: Color

    private let glyphWidth = 5
    private let glyphHeight = 7
    private let characterAdvance = 6
    private let lineAdvance = 8

    var body: some View {
        let metrics = canvasMetrics()
        let maxColumns = lines.map(\.count).max() ?? 0

        Canvas { context, _ in
            for (lineIndex, line) in lines.enumerated() {
                let originY = CGFloat(lineIndex * lineAdvance) * pixelSize
                let centeredOffset = CGFloat(maxColumns - line.count) * CGFloat(characterAdvance) * pixelSize / 2.0

                for (characterIndex, character) in line.enumerated() {
                    let glyph = NESGlyphFont.glyph(for: character)
                    let originX = centeredOffset + (CGFloat(characterIndex * characterAdvance) * pixelSize)

                    for (row, rowBits) in glyph.enumerated() {
                        for column in 0..<glyphWidth {
                            let mask = UInt8(1 << (glyphWidth - 1 - column))
                            guard (rowBits & mask) != 0 else { continue }

                            let rect = CGRect(
                                x: originX + (CGFloat(column) * pixelSize),
                                y: originY + (CGFloat(row) * pixelSize),
                                width: pixelSize,
                                height: pixelSize
                            )
                            context.fill(Path(rect), with: .color(color))
                        }
                    }
                }
            }
        }
        .frame(width: metrics.width, height: metrics.height, alignment: .topLeading)
    }

    private func canvasMetrics() -> CGSize {
        let maxColumns = lines.map(\.count).max() ?? 0
        let widthUnits = max(1, (maxColumns * characterAdvance) - 1)
        let heightUnits = max(1, (max(lines.count, 1) * lineAdvance) - (lineAdvance - glyphHeight))
        return CGSize(width: CGFloat(widthUnits) * pixelSize, height: CGFloat(heightUnits) * pixelSize)
    }
}

private enum NESGlyphFont {
    static func glyph(for character: Character) -> [UInt8] {
        let normalized = Character(String(character).uppercased())
        return glyphs[normalized] ?? glyphs["?"]!
    }

    private static let glyphs: [Character: [UInt8]] = [
        " ": [0, 0, 0, 0, 0, 0, 0],
        "!": [0x04, 0x04, 0x04, 0x04, 0x04, 0x00, 0x04],
        "'": [0x04, 0x04, 0x08, 0x00, 0x00, 0x00, 0x00],
        ",": [0x00, 0x00, 0x00, 0x00, 0x04, 0x04, 0x08],
        "-": [0x00, 0x00, 0x00, 0x0E, 0x00, 0x00, 0x00],
        ".": [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04],
        "?": [0x0E, 0x11, 0x01, 0x02, 0x04, 0x00, 0x04],
        "A": [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
        "B": [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E],
        "C": [0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E],
        "D": [0x1C, 0x12, 0x11, 0x11, 0x11, 0x12, 0x1C],
        "E": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F],
        "F": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10],
        "G": [0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0E],
        "H": [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
        "I": [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E],
        "J": [0x01, 0x01, 0x01, 0x01, 0x11, 0x11, 0x0E],
        "K": [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11],
        "L": [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F],
        "M": [0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11],
        "N": [0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11],
        "O": [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
        "P": [0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10],
        "Q": [0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D],
        "R": [0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11],
        "S": [0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E],
        "T": [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
        "U": [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
        "V": [0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04],
        "W": [0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x0A],
        "X": [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11],
        "Y": [0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04],
        "Z": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F],
        "0": [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
        "1": [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
        "2": [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F],
        "3": [0x1E, 0x01, 0x01, 0x0E, 0x01, 0x01, 0x1E],
        "4": [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
        "5": [0x1F, 0x10, 0x10, 0x1E, 0x01, 0x01, 0x1E],
        "6": [0x0E, 0x10, 0x10, 0x1E, 0x11, 0x11, 0x0E],
        "7": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
        "8": [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
        "9": [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x01, 0x0E]
    ]
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
