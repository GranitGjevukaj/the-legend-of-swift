import SwiftUI
import ZeldaCore

public struct HUDView: View {
    public let state: GameState

    public init(state: GameState) {
        self.state = state
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("LIFE: \(state.link.hearts)/\(state.link.maxHearts)")
                Text("RUPEES: \(state.inventory.rupees)")
                Text("BOMBS: \(state.inventory.bombs)")
            }
            Spacer()
            Text("SCREEN \(state.currentScreen.column),\(state.currentScreen.row)")
        }
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .foregroundStyle(.white)
        .padding(8)
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
    }
}
