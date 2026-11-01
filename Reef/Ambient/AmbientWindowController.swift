import AppKit
import SwiftUI

/// Owns the full-screen ambient window and places it on a chosen screen.
///
/// The window sits at the screen-saver level so it covers the desktop, the menu
/// bar, and other apps while the Mac is idle and unlocked. It is not a secure
/// context, so it steps aside automatically at the real lock screen; this is the
/// unlocked-idle display only.
@MainActor
final class AmbientWindowController {
    private var window: NSWindow?
    private let makeContent: () -> AnyView

    /// True while the window is on screen.
    private(set) var isVisible = false

    init(content: @escaping () -> AnyView) {
        self.makeContent = content
    }

    /// Show the ambient window filling `screen`.
    func show(on screen: NSScreen) {
        let window = window ?? buildWindow()
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        isVisible = true
    }

    /// Take the ambient window off screen.
    func hide() {
        window?.orderOut(nil)
        isVisible = false
    }

    private func buildWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = false
        window.hasShadow = false
        window.isReleasedWhenClosed = false

        let host = NSHostingView(rootView: makeContent())
        host.autoresizingMask = [.width, .height]
        window.contentView = host

        self.window = window
        return window
    }
}
