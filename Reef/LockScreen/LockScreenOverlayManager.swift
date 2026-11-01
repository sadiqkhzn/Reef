import AppKit
import SwiftUI

/// A panel that never takes key or main status, so it can never steal focus from
/// the password field beneath it.
private final class NonKeyPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Shows Reef's ambient content over the lock screen while the Mac is locked.
///
/// The lock shield lives in its own *unmanaged* window-server space, which
/// composites above every ordinary (managed) space — so a normal window, however
/// high its level, stays hidden behind it. To appear over the lock screen the
/// window has to be moved into its own unmanaged space, where it sits in the same
/// tier as the shield and its window level (just above the shield's) wins.
///
/// That is exactly what the comparable notch app does, and the sequence mirrors
/// it precisely: create an unmanaged space, add the window to it, order it front,
/// and keep re-ordering while locked (the shield re-raises itself). On unlock the
/// window is taken back out and the space destroyed. Notably it uses neither
/// `CGSSpaceSetAbsoluteLevel` nor `CGSShowSpaces` — both break the effect.
///
/// It is display-only: it ignores mouse events, never becomes key or main, and
/// never touches the authorization system, so it cannot intercept the password
/// or affect login. Everything is on Reef's own window and own window-server
/// connection, which is permitted with SIP enabled.
///
/// This relies on private CoreGraphics window-server calls (declared in
/// `CGSPrivate.h`), which are not stable across macOS releases, so the feature is
/// opt-in and every teardown path is defensive.
@MainActor
final class LockScreenOverlayManager {
    /// Absolute level for the overlay's space. The lock shield's space is level
    /// 300, so 400 composites just above it. (Matches the comparable notch app.)
    private static let lockSpaceLevel: Int32 = 400

    private let settings: ReefSettings
    private let lockState: LockScreenState
    private let makeContent: () -> AnyView
    /// How long the unlock animation plays before the overlay is removed.
    private let unlockAnimationDuration: TimeInterval = 0.28

    private var panel: NSPanel?
    private var spaceID: CGSSpaceID = 0
    private var observers: [NSObjectProtocol] = []
    /// While locked the shield keeps re-raising, so the window is re-ordered front
    /// on a short interval to stay above it.
    private var reassertTimer: Timer?

    init(settings: ReefSettings, lockState: LockScreenState, content: @escaping () -> AnyView) {
        self.settings = settings
        self.lockState = lockState
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
                MainActor.assumeIsolated { self?.beginUnlock() }
            })
        // Never leave the window in a custom space if the app quits while locked.
        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.hide() }
            })
    }

    func stop() {
        hide()
        let distributed = DistributedNotificationCenter.default()
        for observer in observers {
            distributed.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    // MARK: - Show / hide

    private func show() {
        guard settings.lockScreenOverlay, spaceID == 0 else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        lockState.phase = .locked
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.setFrame(screen.frame, display: true)
        // Realize the window first so it has a valid window number to move.
        panel.orderFrontRegardless()

        // Move the window into a fresh unmanaged space placed above the lock
        // shield's space, so it composites over the lock screen. This is the
        // exact sequence the comparable notch app uses.
        let cid = CGSMainConnectionID()
        // Type 1 = unmanaged space. Type 0 (managed) returns 0 under SIP.
        let space = CGSSpaceCreate(cid, 1, nil)
        guard space != 0 else { return }
        spaceID = space
        let spaceArray = [NSNumber(value: space)] as CFArray
        // The shield lives in a space at level 300; 400 sits just above it.
        CGSSpaceSetAbsoluteLevel(cid, space, Self.lockSpaceLevel)
        CGSShowSpaces(cid, spaceArray)
        CGSAddWindowsToSpaces(cid, [NSNumber(value: panel.windowNumber)] as CFArray, spaceArray)
        panel.orderFrontRegardless()

        // Keep re-raising above the shield, which re-asserts itself while locked.
        reassertTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel else { return }
                panel.orderFrontRegardless()
                // Force the content to redraw; while occluded, drawing is deferred.
                panel.contentView?.needsDisplay = true
                panel.displayIfNeeded()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        reassertTimer = timer
    }

    /// Play the unlock animation, then remove the overlay. The desktop is
    /// already visible behind the (now transparent) overlay once the shield
    /// drops, so this just shows the lock opening before clearing.
    private func beginUnlock() {
        guard spaceID != 0 else { hide(); return }
        lockState.phase = .unlocking
        DispatchQueue.main.asyncAfter(deadline: .now() + unlockAnimationDuration) { [weak self] in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    private func hide() {
        reassertTimer?.invalidate()
        reassertTimer = nil
        // Do not reset the phase here: that would flip the content back to its
        // locked state and flash it onto the desktop as the window is removed.
        // show() sets .locked at the start of the next lock.

        if spaceID != 0 {
            let cid = CGSMainConnectionID()
            let spaceArray = [NSNumber(value: spaceID)] as CFArray
            if let panel {
                let windows = [NSNumber(value: panel.windowNumber)] as CFArray
                CGSRemoveWindowsFromSpaces(cid, windows, spaceArray)
            }
            CGSHideSpaces(cid, spaceArray)
            CGSSpaceDestroy(cid, spaceID)
            spaceID = 0
        }
        panel?.orderOut(nil)
    }

    // MARK: - Panel

    private func makePanel() -> NSPanel {
        let panel = NonKeyPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false)
        // Transparent so the live lock wallpaper shows through behind the content.
        // The re-assert timer forces redraws, which is what makes the SwiftUI
        // content paint while the app is occluded during lock.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Accept mouse events so the card's transport controls work. Only the
        // card is hit-testable (everything else uses allowsHitTesting(false)),
        // and the panel never becomes key, so clicks elsewhere and the password
        // field / Touch ID are unaffected.
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        // Above the lock shield's window level; the space move is what lets this
        // level actually take effect over the lock screen.
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        panel.collectionBehavior = [
            .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle,
        ]

        let host = NSHostingView(rootView: makeContent())
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        return panel
    }
}
