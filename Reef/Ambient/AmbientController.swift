import AppKit
import Combine
import SwiftUI

/// Shows the ambient display when the Mac is idle, and dismisses it on the next
/// input or when turned off.
///
/// It drives an `IdleMonitor` from the person's settings: when idle crosses the
/// chosen delay the window appears on the active screen, and the first key or
/// pointer event takes it away again. It can also be shown on demand (a menu
/// item, or the settings preview), which is dismissed the same way.
@MainActor
final class AmbientController: ObservableObject {
    private let settings: ReefSettings
    private let idle = IdleMonitor()
    private let windowController: AmbientWindowController
    private var cancellables: Set<AnyCancellable> = []
    private var eventMonitors: [Any] = []
    /// A backstop poll that hides the display as soon as any input is seen,
    /// independent of the event monitors, so it can never linger.
    private var inputPoll: Timer?
    /// When the display was shown, so the input that triggered it (the click on
    /// the menu, or the move that will dismiss it) does not dismiss it instantly.
    private var shownAt: Date?
    /// How long to ignore input right after showing, so an on-demand show is not
    /// closed by the very interaction that opened it.
    private let dismissGrace: TimeInterval = 1.5

    /// True once enough time has passed since showing that input should dismiss.
    private var dismissalArmed: Bool {
        guard let shownAt else { return false }
        return Date().timeIntervalSince(shownAt) >= dismissGrace
    }

    init(settings: ReefSettings, content: @escaping () -> AnyView) {
        self.settings = settings
        self.windowController = AmbientWindowController(content: content)
    }

    func start() {
        idle.onIdleChange = { [weak self] isIdle in
            guard let self else { return }
            if isIdle {
                self.showIfEnabled()
            } else {
                self.hide()
            }
        }
        applyThreshold()
        observeSettings()
        if settings.ambientEnabled {
            idle.start()
        }
    }

    /// Show the ambient display now, regardless of idle (menu item, preview).
    func showNow() {
        show()
    }

    // MARK: - Settings

    private func observeSettings() {
        settings.$ambientEnabled
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    self.idle.start()
                } else {
                    self.idle.stop()
                    self.hide()
                }
            }
            .store(in: &cancellables)

        settings.$ambientIdleMinutes
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.applyThreshold() }
            .store(in: &cancellables)
    }

    private func applyThreshold() {
        idle.threshold = TimeInterval(max(1, settings.ambientIdleMinutes) * 60)
    }

    // MARK: - Show / hide

    private func showIfEnabled() {
        guard settings.ambientEnabled else { return }
        show()
    }

    private func show() {
        guard !windowController.isVisible else { return }
        guard let screen = NotchWindowController.activeScreen(for: settings.displayTarget) else {
            return
        }
        windowController.show(on: screen)
        watchForInput()
    }

    private func hide() {
        guard windowController.isVisible else { return }
        windowController.hide()
        stopWatchingForInput()
    }

    /// While the ambient display is up, the first key or pointer event dismisses
    /// it at once, rather than waiting for the idle poll to notice.
    private func watchForInput() {
        guard eventMonitors.isEmpty else { return }
        shownAt = Date()
        let mask: NSEvent.EventTypeMask = [
            .keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel,
        ]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.dismissIfArmed() }
        }) {
            eventMonitors.append(global)
        }
        // A local monitor covers input that lands on the ambient window itself.
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.dismissIfArmed() }
            return event
        }) {
            eventMonitors.append(local)
        }

        // Backstop: poll the HID idle time and hide the moment input returns,
        // even if the monitors miss it (for example a keyDown without Input
        // Monitoring permission, or the on-demand show with no idle poll running).
        let poll = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.dismissalArmed else { return }
                if IdleMonitor.idleSeconds() < 1 { self.hide() }
            }
        }
        RunLoop.main.add(poll, forMode: .common)
        inputPoll = poll
    }

    /// Hide on input, but only once the grace period after showing has passed, so
    /// the interaction that opened the display does not immediately close it.
    private func dismissIfArmed() {
        if dismissalArmed { hide() }
    }

    private func stopWatchingForInput() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
        inputPoll?.invalidate()
        inputPoll = nil
        shownAt = nil
    }
}
