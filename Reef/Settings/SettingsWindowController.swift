import AppKit
import SwiftUI

/// Owns the settings window.
///
/// Reef runs as an accessory with no Dock icon, so the standard Settings
/// scene is hard to reach. The menu bar item opens this window instead, and it
/// is kept around after closing so it reopens where it was.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let makeContent: () -> AnyView

    init<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        makeContent = { AnyView(content()) }
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 760, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.title = "Reef Settings"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: makeContent())
        window.setContentSize(CGSize(width: 760, height: 540))
        window.center()
        window.setFrameAutosaveName("ReefSettings")
        return window
    }
}
