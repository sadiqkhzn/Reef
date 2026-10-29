import AppKit
import Combine
import SwiftUI

/// Owns the overlay panel and keeps it in the right place.
///
/// The panel stays at a fixed size that is large enough for the open overlay.
/// It never resizes while opening or closing; the SwiftUI content animates the
/// silhouette inside it. The controller only moves the panel onto the active
/// screen, resizes it when the display layout or the overlay style changes,
/// and keeps the panel's click-through region in step with the current state.
@MainActor
final class NotchWindowController {
    private let panel: NotchPanel
    private let container: OverlayContainerView
    private let state: NotchState
    private let settings: ReefSettings
    private var cancellables: Set<AnyCancellable> = []

    /// Slack on each side and below the overlay so the fixed panel has room for
    /// the open state, the notch shoulders, and the floating shadow.
    private let panelSidePadding: CGFloat = 48
    private let panelBottomPadding: CGFloat = 20

    /// Dwell on the bare island before it opens on its own. Hovering only peeks;
    /// a click opens it at once, so this is a long fallback rather than the main
    /// way in.
    private let openDelay: TimeInterval = 3.0
    /// Short grace period before it closes, so crossing an inner edge does not
    /// make it flicker shut.
    private let closeDelay: TimeInterval = 0.2
    private var phaseWork: DispatchWorkItem?

    /// The screen the overlay is currently placed on, used to notice when the
    /// pointer moves to another display.
    private var lastScreenFrame: CGRect?
    private var screenFollowTimer: Timer?

    init(
        state: NotchState, settings: ReefSettings, battery: BatteryModel,
        calendar: CalendarMonitor, weather: WeatherProvider, shelf: ShelfModel
    ) {
        self.state = state
        self.settings = settings

        let initialSize = CGSize(width: 420, height: 200)
        panel = NotchPanel(contentRect: CGRect(origin: .zero, size: initialSize))

        container = OverlayContainerView(frame: CGRect(origin: .zero, size: initialSize))
        container.autoresizesSubviews = true

        let host = NSHostingView(
            rootView: AnyView(
                OverlayRootView()
                    .environmentObject(state)
                    .environmentObject(settings)
                    .environmentObject(battery)
                    .environmentObject(calendar)
                    .environmentObject(weather)
                    .environmentObject(shelf)))
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        panel.contentView = container

        observeScreenChanges()
        observeHover()
        observePhase()
        observeLiveActivity()
        observeNowPlaying()
        observeStyle()
        followActiveScreen()
        reposition()
    }

    /// Put the overlay on screen.
    func show() {
        panel.orderFrontRegardless()
    }

    // MARK: - Screen selection

    /// The screen the overlay should appear on: the one under the pointer, then
    /// the main screen, then the first attached screen. When the lid is closed
    /// the main screen is the external display, which is what we want.
    static func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        let underPointer = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
        return underPointer ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func notch(for screen: NSScreen) -> ScreenMetrics.Notch {
        ScreenMetrics.notch(
            safeAreaTop: screen.safeAreaInsets.top,
            screenWidth: screen.frame.width,
            leftAreaWidth: screen.auxiliaryTopLeftArea?.width,
            rightAreaWidth: screen.auxiliaryTopRightArea?.width)
    }

    private func menuBarHeight(for screen: NSScreen) -> CGFloat {
        max(0, screen.frame.maxY - screen.visibleFrame.maxY)
    }

    // MARK: - Sizing

    /// Fixed panel size for a screen. Wide and tall enough for the open overlay
    /// and for the resting overlay with its wings spread, with a little slack
    /// around it.
    private func panelSize(collapsed: CGSize) -> CGSize {
        let open = NotchState.expandedSize(collapsed: collapsed)
        let winged = collapsed.width + NotchState.wingWidth * 2 + NotchState.peekGrow.width
        return CGSize(
            width: max(open.width, winged) + panelSidePadding,
            height: open.height + panelBottomPadding)
    }

    // MARK: - Positioning

    private func reposition() {
        guard let screen = NotchWindowController.activeScreen() else { return }

        let style = settings.overlayStyle
        let notch = notch(for: screen)
        state.hasNotch = notch.exists
        // Update the drawn style here, while the overlay is hidden during a
        // style change, so the shape changes together with the size and position.
        state.displayedStyle = style
        switch style {
        case .attached:
            if notch.exists {
                // Hug the real notch exactly.
                state.collapsedSize = ScreenMetrics.collapsedSize(
                    for: notch,
                    menuBarHeight: menuBarHeight(for: screen))
            } else {
                // No notch to hug: sit inside the menu bar strip with a small
                // bottom gap so it does not touch window content, like floating.
                let stripHeight = menuBarHeight(for: screen)
                state.collapsedSize = CGSize(
                    width: ScreenMetrics.defaultPillWidth,
                    height: max(18, stripHeight - 5))
            }
        case .floating:
            // Keep the floating bubble inside the menu bar strip with equal gaps
            // above and below, so it is centered in the strip and never crosses
            // into app windows.
            let stripHeight = menuBarHeight(for: screen)
            let height = max(18, stripHeight - style.topGap * 2)
            state.collapsedSize = CGSize(
                width: OverlayStyle.floatingRestingSize.width,
                height: height)
        }

        // The panel is anchored near the top of the screen. The attached style
        // sits flush against the top edge, hugging the notch or filling the menu
        // bar strip; the floating style drops a few points below so the bubble
        // reads as detached. Either way the overlay stays out of app windows
        // until it is opened.
        let size = panelSize(collapsed: state.collapsedSize)
        let x = screen.frame.minX + (screen.frame.width - size.width) / 2
        let originY = screen.frame.maxY - size.height - style.topGap
        panel.setFrame(
            CGRect(x: x, y: originY, width: size.width, height: size.height),
            display: true,
            animate: false)

        lastScreenFrame = screen.frame
        updateInteractiveRect()
    }

    /// Keep the panel's clickable and hover-sensing region matched to the
    /// overlay. The overlay is anchored to the top center of the panel, so the
    /// region sits flush with the top.
    private func updateInteractiveRect() {
        let size = state.hitSize
        let panelSize = panel.frame.size
        container.interactiveRect = CGRect(
            x: (panelSize.width - size.width) / 2,
            y: panelSize.height - size.height,
            width: size.width,
            height: size.height)
    }

    // MARK: - Observation

    private func observeScreenChanges() {
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.reposition() }
            .store(in: &cancellables)
    }

    /// Turn hover into peek and, eventually, open.
    ///
    /// Hovering only peeks (the small grow is handled in the view). The island
    /// opens fully only after a long dwell on the bare island, or on a click.
    /// Hovering an interactive control does not open it: moving onto a control
    /// cancels the pending open, and moving back to the bare island starts the
    /// dwell again. Leaving closes it after a short grace period.
    private func observeHover() {
        Publishers.CombineLatest(state.$isHovering, state.$isOverControl)
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] hovering, overControl in
                guard let self else { return }
                self.phaseWork?.cancel()

                if hovering && !overControl {
                    let work = DispatchWorkItem { [weak self] in
                        guard let self, self.state.isHovering, !self.state.isOverControl else { return }
                        self.state.phase = .expanded
                    }
                    self.phaseWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.openDelay, execute: work)
                } else if !hovering {
                    let work = DispatchWorkItem { [weak self] in
                        guard let self, !self.state.isHovering else { return }
                        self.state.phase = .collapsed
                    }
                    self.phaseWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.closeDelay, execute: work)
                }
                // Hovering a control: keep the current phase (peek), open nothing.
            }
            .store(in: &cancellables)
    }

    /// Keep the click-through region in step with the phase. The panel does not
    /// resize; only the interactive area changes.
    private func observePhase() {
        state.$phase
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateInteractiveRect()
            }
            .store(in: &cancellables)
    }

    /// The wings widen the resting overlay and the quick peek deepens it, so
    /// the hover region follows both.
    private func observeLiveActivity() {
        state.$liveActivity
            .removeDuplicates()
            .map { _ in () }
            .merge(with: state.$isPeeking.removeDuplicates().map { _ in () })
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.updateInteractiveRect()
            }
            .store(in: &cancellables)
    }

    /// The media wing widens the resting overlay too, so the hover region
    /// follows it.
    private func observeNowPlaying() {
        state.$nowPlayingActive
            .removeDuplicates()
            .map { _ in () }
            .merge(with: state.$announcingTitle.map { _ in () })
            .merge(with: state.$eventRestingActive.removeDuplicates().map { _ in () })
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateInteractiveRect()
            }
            .store(in: &cancellables)
    }

    /// Switching between attached and floating changes the shape, resting size,
    /// and panel position. Rather than morph the shape (the shoulders flashing),
    /// fade the old island out, swap everything while it is hidden, and let the
    /// new one fade in fresh. The drawn style changes inside `reposition`, which
    /// runs at the hidden point, so nothing morphs.
    private func observeStyle() {
        settings.$overlayStyle
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.relocate()
            }
            .store(in: &cancellables)
    }

    /// Follow the pointer to whichever screen it is on, like the menu bar does.
    /// Polling the pointer location is simple and dependable across apps that do
    /// or do not themselves track the mouse.
    private func followActiveScreen() {
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, let screen = NotchWindowController.activeScreen() else { return }
            guard screen.frame != self.lastScreenFrame else { return }

            // Claim the new screen right away so the timer does not fire again
            // mid-hop, then play the fade-and-pop across.
            self.lastScreenFrame = screen.frame
            self.relocate()
        }
        RunLoop.main.add(timer, forMode: .common)
        screenFollowTimer = timer
    }

    /// Fade and shrink the overlay out, move it to the active screen while it is
    /// invisible, then let it pop back in there.
    private func relocate() {
        state.isRelocating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [weak self] in
            guard let self else { return }
            self.reposition()
            self.state.isRelocating = false
        }
    }
}
