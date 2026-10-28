import AppKit
import Combine
import SwiftUI

/// Owns the overlay panel and keeps it in the right place.
///
/// It measures the active screen, sizes the collapsed overlay to match the
/// notch when there is one, and recenters the panel whenever the phase changes
/// or the display layout changes (an external monitor arriving, the lid
/// closing, resolution changes).
@MainActor
final class NotchWindowController {
    private let panel: NotchPanel
    private let state: NotchState
    private let hostingView: NSHostingView<AnyView>
    private var cancellables: Set<AnyCancellable> = []

    /// Small extra gap below the menu bar on Macs without a notch, so the pill
    /// has a little breathing room rather than touching it.
    private let floatingBottomPadding: CGFloat = 2

    /// How long the open and close animation runs. The panel waits this long
    /// before it shrinks on close so the content is not clipped mid-animation.
    private let phaseAnimationDuration: TimeInterval = 0.45

    init(state: NotchState) {
        self.state = state

        let screen = NotchWindowController.activeScreen()
        let startFrame = ScreenMetrics.overlayFrame(
            screenFrame: screen?.frame ?? .zero,
            size: ScreenMetrics.defaultPillSize)

        panel = NotchPanel(contentRect: startFrame)

        let root = AnyView(OverlayRootView().environmentObject(state))
        hostingView = NSHostingView(rootView: root)
        hostingView.frame = CGRect(origin: .zero, size: startFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        observeScreenChanges()
        observeHover()
        observePhase()
        reposition()
    }

    /// Put the overlay on screen.
    func show() {
        panel.orderFrontRegardless()
    }

    // MARK: - Screen selection

    /// The screen the overlay should appear on.
    ///
    /// Preference order: the screen the pointer is on, then the main screen,
    /// then the first attached screen. When the laptop lid is closed the main
    /// screen is the external display, which is what we want.
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

    // MARK: - Positioning

    private func reposition() {
        guard let screen = NotchWindowController.activeScreen() else { return }

        let notch = notch(for: screen)
        state.collapsedSize = ScreenMetrics.collapsedSize(for: notch)

        // On a notched Mac the overlay hugs the notch at the very top edge. On
        // a Mac without a notch it sits just below the menu bar so it stays
        // fully visible instead of hiding behind it.
        let inset: CGFloat = notch.exists ? 0 : menuBarHeight(for: screen) + floatingBottomPadding
        let frame = ScreenMetrics.overlayFrame(
            screenFrame: screen.frame,
            size: state.targetSize,
            topInset: inset)

        panel.setFrame(frame, display: true, animate: false)
    }

    /// Height of the menu bar on a screen, measured as the gap between the top
    /// of the screen and the top of its usable area.
    private func menuBarHeight(for screen: NSScreen) -> CGFloat {
        max(0, screen.frame.maxY - screen.visibleFrame.maxY)
    }

    private func observeScreenChanges() {
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.reposition() }
            .store(in: &cancellables)
    }

    /// Turn hover into an open or closed phase. A short settle time avoids the
    /// overlay flickering open when the pointer only grazes the notch.
    private func observeHover() {
        state.$isHovering
            .removeDuplicates()
            .debounce(for: .milliseconds(90), scheduler: RunLoop.main)
            .sink { [weak self] hovering in
                guard let self else { return }
                self.state.phase = hovering ? .expanded : .collapsed
            }
            .store(in: &cancellables)
    }

    /// Resize the panel around the phase change. Opening grows the panel at
    /// once so the content has room to expand into. Closing keeps the panel
    /// large until the animation finishes, then shrinks it back to the pill.
    private func observePhase() {
        state.$phase
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                guard let self else { return }
                switch phase {
                case .expanded:
                    self.reposition()
                case .collapsed:
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.phaseAnimationDuration) {
                        if self.state.phase == .collapsed {
                            self.reposition()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
}
