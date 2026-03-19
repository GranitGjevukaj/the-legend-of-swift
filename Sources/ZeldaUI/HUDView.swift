import SwiftUI
import ZeldaCore

public struct HUDView: View {
    public let state: GameState

    public init(state: GameState) {
        self.state = state
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            MiniMapPanel(screen: state.currentScreen)

            VStack(alignment: .leading, spacing: 6) {
                HUDCounter(label: "X\(state.inventory.rupees)", color: Color(red: 0.95, green: 0.74, blue: 0.30)) {
                    Diamond()
                        .fill(Color(red: 0.95, green: 0.74, blue: 0.30))
                        .frame(width: 9, height: 9)
                }

                HUDCounter(label: "X\(state.inventory.keys)", color: Color(red: 0.88, green: 0.66, blue: 0.25)) {
                    KeyShape()
                        .stroke(Color(red: 0.88, green: 0.66, blue: 0.25), lineWidth: 2)
                        .frame(width: 12, height: 10)
                }

                HUDCounter(label: "X\(state.inventory.bombs)", color: Color(red: 0.30, green: 0.38, blue: 0.92)) {
                    Circle()
                        .fill(Color(red: 0.30, green: 0.38, blue: 0.92))
                        .frame(width: 11, height: 11)
                }
            }
            .padding(.top, 4)

            HStack(spacing: 10) {
                ItemSlotView(title: "B", accent: Color(red: 0.32, green: 0.36, blue: 0.95), kind: nil)
                ItemSlotView(title: "A", accent: Color(red: 0.32, green: 0.36, blue: 0.95), kind: swordKind)
            }
            .padding(.top, 2)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                Text("-LIFE-")
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(red: 0.83, green: 0.36, blue: 0.26))

                HeartsRow(current: state.link.hearts, maximum: state.link.maxHearts)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Rectangle()
                .fill(Color.black)
        )
    }

    private var swordKind: ItemDefinition.Kind? {
        switch state.inventory.swordLevel {
        case 3:
            return .magicSword
        case 2:
            return .whiteSword
        case 1:
            return .woodenSword
        default:
            return nil
        }
    }
}

private struct MiniMapPanel: View {
    let screen: ScreenCoordinate

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let dotX = ((CGFloat(screen.column) + 0.5) / 16.0) * width
            let dotY = ((CGFloat(screen.row) + 0.5) / 8.0) * height

            ZStack {
                Rectangle()
                    .fill(Color(red: 0.62, green: 0.62, blue: 0.62))

                Rectangle()
                    .fill(Color(red: 0.56, green: 0.83, blue: 0.16))
                    .frame(width: 8, height: 8)
                    .position(x: dotX, y: dotY)
            }
        }
        .frame(width: 118, height: 56)
        .overlay(
            Rectangle()
                .stroke(Color.black, lineWidth: 3)
        )
    }
}

private struct HUDCounter<Icon: View>: View {
    let label: String
    let color: Color
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        HStack(spacing: 6) {
            icon()
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(minWidth: 72, alignment: .leading)
    }
}

private struct ItemSlotView: View {
    let title: String
    let accent: Color
    let kind: ItemDefinition.Kind?

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)

            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(accent, lineWidth: 4)
                    .frame(width: 44, height: 58)

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.black)
                    .frame(width: 34, height: 48)

                if let kind {
                    ItemGlyph(kind: kind)
                }
            }
        }
    }
}

private struct HeartsRow: View {
    let current: Int
    let maximum: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<maximum, id: \.self) { index in
                Text(index < current ? "♥" : "♡")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.83, green: 0.36, blue: 0.26))
            }
        }
    }
}

private struct ItemGlyph: View {
    let kind: ItemDefinition.Kind

    var body: some View {
        switch kind {
        case .woodenSword:
            SwordGlyph(blade: Color.white, hilt: Color(red: 0.73, green: 0.46, blue: 0.20))
        case .whiteSword:
            SwordGlyph(blade: Color(red: 0.80, green: 0.89, blue: 1.0), hilt: Color(red: 0.73, green: 0.46, blue: 0.20))
        case .magicSword:
            SwordGlyph(blade: Color(red: 0.38, green: 0.75, blue: 1.0), hilt: Color(red: 0.91, green: 0.76, blue: 0.28))
        case .bomb:
            Circle()
                .fill(Color(red: 0.30, green: 0.38, blue: 0.92))
                .frame(width: 14, height: 14)
        case .boomerang:
            Text(")")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0.83, green: 0.54, blue: 0.24))
        case .candle:
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.85, green: 0.46, blue: 0.18))
                .frame(width: 10, height: 18)
        case .bow:
            Text("}")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0.83, green: 0.54, blue: 0.24))
        case .raft, .ladder, .powerBracelet:
            Rectangle()
                .fill(Color(red: 0.62, green: 0.62, blue: 0.62))
                .frame(width: 14, height: 14)
        }
    }
}

private struct SwordGlyph: View {
    let blade: Color
    let hilt: Color

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(blade)
                .frame(width: 4, height: 20)

            Rectangle()
                .fill(hilt)
                .frame(width: 12, height: 4)

            Rectangle()
                .fill(hilt)
                .frame(width: 4, height: 7)
        }
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct KeyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bowRadius = min(rect.width, rect.height) * 0.32
        let bowCenter = CGPoint(x: rect.minX + bowRadius + 1, y: rect.midY)
        path.addEllipse(in: CGRect(
            x: bowCenter.x - bowRadius,
            y: bowCenter.y - bowRadius,
            width: bowRadius * 2,
            height: bowRadius * 2
        ))
        path.move(to: CGPoint(x: bowCenter.x + bowRadius, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - 2))
        path.move(to: CGPoint(x: rect.maxX - 5, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - 5, y: rect.maxY - 4))
        return path
    }
}
