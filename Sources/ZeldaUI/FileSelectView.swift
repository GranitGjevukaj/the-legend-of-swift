import SwiftUI

public struct FileSelectView: View {
    public var onSelectSlot: (Int) -> Void

    public init(onSelectSlot: @escaping (Int) -> Void) {
        self.onSelectSlot = onSelectSlot
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Select A File")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                ForEach(0..<3, id: \.self) { slot in
                    Button("Slot \(slot + 1)") {
                        onSelectSlot(slot)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(Color(red: 0.95, green: 0.84, blue: 0.44))
                    .foregroundStyle(Color(red: 0.95, green: 0.84, blue: 0.44))
                }
            }
        }
    }
}
