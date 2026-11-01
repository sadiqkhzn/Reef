import AppKit
import SwiftUI

/// Owns the welcome window shown on first launch.
///
/// Like the settings window, it is kept around after closing so it can be shown
/// again from the menu. Finishing it (Get Started or closing the window) records
/// that onboarding is done and calls `onFinish` once.
@MainActor
final class OnboardingWindowController: NSObject {
    /// Called once when onboarding is finished, so the app can start the
    /// services that ask for permission after the person has had a say.
    var onFinish: (() -> Void)?

    private var window: NSWindow?
    private let permissions = PermissionsModel()
    private var finished = false

    /// Whether onboarding has already been completed.
    static var hasOnboarded: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    private static let key = "onboarding.done"

    func show() {
        permissions.refresh()
        let window = self.window ?? makeWindow()
        self.window = window
        // Bring the welcome window back to the front after each system prompt,
        // which otherwise leaves it behind other windows.
        permissions.onResolved = { [weak self] in self?.reactivate() }
        reactivate()
        window.center()
    }

    private func reactivate() {
        // A few nudges after a system dialog dismisses: the first can land while
        // it is still animating away, so later ones make sure the window comes
        // back to the front.
        for delay in [0.0, 0.25, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                NSApp.activate(ignoringOtherApps: true)
                self?.window?.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func complete() {
        guard !finished else { return }
        finished = true
        Self.hasOnboarded = true
        onFinish?()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 460, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.title = "Welcome to Reef"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: OnboardingView(permissions: permissions) { [weak self] in self?.window?.close() })
        window.setContentSize(CGSize(width: 460, height: 600))
        return window
    }
}

extension OnboardingWindowController: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in self.complete() }
    }
}
