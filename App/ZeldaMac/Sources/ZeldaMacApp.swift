import AppKit
import SwiftUI
import ZeldaUI

@main
struct ZeldaMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ZeldaRootView()
                .frame(minWidth: 800, minHeight: 560)
        }
        .windowStyle(.titleBar)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        activateGameWindow()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.activateGameWindow()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.activateGameWindow()
        }
    }

    private func activateGameWindow() {
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)

        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
