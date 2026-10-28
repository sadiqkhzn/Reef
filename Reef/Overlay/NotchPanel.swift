import AppKit

/// The window the overlay lives in.
///
/// It is a borderless, non-activating panel pinned at the status bar level, so
/// it floats over ordinary windows, shows up on every Space, and never takes
/// keyboard focus away from whatever the person is working in. It still accepts
/// mouse events so the overlay can react to hover and clicks.
final class NotchPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)

        isFloatingPanel = true
        level = .statusBar
        // Appear on every Space, but mark the panel transient so macOS hides it
        // during Mission Control, App Expose, and Show Desktop instead of
        // pinning it on top of them.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        isMovable = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
    }

    // A borderless panel refuses key status by default; make that explicit so
    // the overlay never steals focus even when clicked.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
