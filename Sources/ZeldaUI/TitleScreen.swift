import SwiftUI

public struct TitleScreen: View {
    public var onStart: () -> Void

    public init(onStart: @escaping () -> Void) {
        self.onStart = onStart
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.05, blue: 0.02), Color(red: 0.28, green: 0.12, blue: 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("THE LEGEND OF SWIFT")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.45))
                    .multilineTextAlignment(.center)

                Text("A native macOS reinterpretation")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                Button("Start") {
                    onStart()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color(red: 0.78, green: 0.22, blue: 0.16))
            }
            .padding(32)
        }
    }
}
