import AppKit
import SwiftUI

/// Shows Reef's ambient content over the lock shield while the Mac is locked.
///
/// This does not inject into the secure login UI and never touches the
/// authorization system. It raises an ordinary borderless window to the public
/// screen-shield level (`CGShieldingWindowLevel`) when the session locks, and
/// takes it away when it unlocks. The window ignores mouse events and shows only
/// information, so it can neither intercept the password nor affect login; the
/// real authenticator runs underneath as usual. If macOS hides shield-level
/// windows during secure authentication, it simply does not appear.
@MainActor
final class LockScreenOverlayManager {
    private let settings: ReefSettings
    private let makeContent: () -> AnyView
    private var window: NSWindow?
    private var observers: [NSObjectProtocol] = []

    init(settings: ReefSettings, content: @escaping () -> AnyView) {
        self.settings = settings
        self.makeContent = content
    }

    func start() {
        let center = DistributedNotificationCenter.default()
        observers.append(
            center.addObserver(
                forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.show() }
            })
        observers.append(
            center.addObserver(
                forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.hide() }
            })
    }

    func stop() {
        let center = DistributedNotificationCenter.default()
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        hide()
    }

    private func show() {
        guard settings.lockScreenOverlay else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let window = self.window ?? makeWindow()
        self.window = window
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
    }

    private func hide() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        // The public screen-shield level: a window here sits above the lock
        // shield. Display only; it cannot touch the authentication beneath it.
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let host = NSHostingView(rootView: makeContent())
        host.autoresizingMask = [.width, .height]
        window.contentView = host
        return window
    }
}
