import AppKit
import Combine
import SwiftUI

/// Owns the overlay panel and keeps it in the right place.
///
/// The panel stays at a fixed size that is large enough for the open overlay.
/// It never resizes while opening or closing; the SwiftUI content animates the
/// silhouette inside it. The controller only moves the panel onto the active
/// screen, resizes it when the display layout changes, and keeps the panel's
/// click-through region in step with the current phase.
@MainActor
final class NotchWindowController {
    private let panel: NotchPanel
    private let container: OverlayContainerView
    private let state: NotchState
    private var cancellables: Set<AnyCancellable> = []

    /// Slack on each side and below the overlay so the fixed panel has room for
    /// the open state and a little breathing space.
    private let panelSidePadding: CGFloat = 48
    private let panelBottomPadding: CGFloat = 12

    /// Pause before the overlay opens after the pointer arrives, so a passing
    /// pointer does not open it. The quick grow on hover covers this pause.
    private let openDelay: TimeInterval = 0.2
    /// Short grace period before it closes, so crossing an inner edge does not
    /// make it flicker shut.
    private let closeDelay: TimeInterval = 0.15
    private var phaseWork: DispatchWorkItem?

    /// The screen the overlay is currently placed on, used to notice when the
    /// pointer moves to another display.
    private var lastScreenFrame: CGRect?
    private var screenFollowTimer: Timer?

    init(state: NotchState) {
        self.state = state

        let initialSize = CGSize(width: 420, height: 200)
        panel = NotchPanel(contentRect: CGRect(origin: .zero, size: initialSize))

        container = OverlayContainerView(frame: CGRect(origin: .zero, size: initialSize))
        container.autoresizesSubviews = true

        let host = NSHostingView(
            rootView: AnyView(OverlayRootView().environmentObject(state)))
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        panel.contentView = container

        observeScreenChanges()
        observeHover()
        observePhase()
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

    /// Fixed panel size for a screen. Wide and tall enough for the open overlay,
    /// with a little slack around it.
    private func panelSize(collapsed: CGSize) -> CGSize {
        let openWidth = max(collapsed.width, NotchState.expandedMinWidth)
        return CGSize(
            width: openWidth + panelSidePadding,
            height: NotchState.expandedHeight + panelBottomPadding)
    }

    // MARK: - Positioning

    private func reposition() {
        guard let screen = NotchWindowController.activeScreen() else { return }

        let notch = notch(for: screen)
        switch OverlayStyle.current {
        case .attached:
            state.collapsedSize = ScreenMetrics.collapsedSize(
                for: notch,
                menuBarHeight: menuBarHeight(for: screen))
        case .floating:
            // Keep the floating bubble inside the menu bar strip with equal gaps
            // above and below, so it is centered in the strip and never crosses
            // into app windows.
            let stripHeight = menuBarHeight(for: screen)
            let height = max(18, stripHeight - OverlayStyle.current.topGap * 2)
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
        let originY = screen.frame.maxY - size.height - OverlayStyle.current.topGap
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

    /// Turn hover into an open or closed phase. Opening waits a short pause so a
    /// passing pointer does not open it; closing waits a shorter grace period so
    /// it does not flicker shut when the pointer crosses an inner edge. The
    /// quick grow on hover is handled in the view and happens at once.
    private func observeHover() {
        state.$isHovering
            .removeDuplicates()
            .sink { [weak self] hovering in
                guard let self else { return }
                self.phaseWork?.cancel()

                let target: NotchState.Phase = hovering ? .expanded : .collapsed
                let delay = hovering ? self.openDelay : self.closeDelay
                let work = DispatchWorkItem { [weak self] in
                    self?.state.phase = target
                }
                self.phaseWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
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
