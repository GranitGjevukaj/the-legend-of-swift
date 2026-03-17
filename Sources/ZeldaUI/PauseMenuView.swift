import SwiftUI

public struct PauseMenuView: View {
    public var onResume: () -> Void

    public init(onResume: @escaping () -> Void) {
        self.onResume = onResume
    }

    public var body: some View {
        VStack(spacing: 10) {
            Text("Paused")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
            Button("Resume") {
                onResume()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
