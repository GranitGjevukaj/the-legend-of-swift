import SwiftUI
import ZeldaUI

@main
struct ZeldaMacApp: App {
    var body: some Scene {
        WindowGroup {
            ZeldaRootView()
                .frame(minWidth: 800, minHeight: 560)
        }
        .windowStyle(.titleBar)
    }
}
