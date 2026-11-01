import SwiftUI

/// Shared, observable state for the overlay.
///
/// Views read from it, and the window controller watches it so it can keep the
/// panel's click-through region in step as the overlay opens, closes, or
/// spreads its wings for a live activity.
final class NotchState: ObservableObject {

    /// How open the overlay is right now.
    enum Phase: Equatable {
        case collapsed
        case expanded
    }

    @Published var phase: Phase = .collapsed

    /// True while the pointer is over the overlay.
    @Published var isHovering: Bool = false

    /// True for the brief moment while the overlay is hopping to another screen,
    /// used to fade and pop it across instead of teleporting.
    @Published var isRelocating: Bool = false

    /// True when the overlay sits on a screen with a hardware notch.
    @Published var hasNotch: Bool = false

    /// The style the overlay is drawn in right now. The window controller sets
    /// this during a reposition, which runs while the overlay is hidden, so a
    /// style change swaps the shape, size, and position together with no flash.
    @Published var displayedStyle: OverlayStyle = .attached

    /// True while the pointer is over an interactive control inside the island
    /// (a button), so hovering a control does not open the island.
    @Published var isOverControl: Bool = false

    /// True while a track is playing or paused, so the resting overlay widens to
    /// show the media wing (cover and equalizer).
    @Published var nowPlayingActive: Bool = false

    /// A track title to announce briefly (on resume): it shows at peek size,
    /// scrolling until seen, then clears on its own.
    @Published var announcingTitle: String?
    private var announceWork: DispatchWorkItem?

    /// Briefly show a track title, then clear it. Held long enough to scroll
    /// through plus a short pause.
    func announce(_ title: String) {
        announceWork?.cancel()
        announcingTitle = title
        // Fixed hold regardless of title length.
        let work = DispatchWorkItem { [weak self] in self?.announcingTitle = nil }
        announceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }

    /// Extra height added while announcing: equal to the resting height, so the
    /// island becomes twice as tall, same width and curvature.
    var announcementBannerHeight: CGFloat { collapsedSize.height }

    /// The live activity shown in the wings while resting, if any.
    @Published var liveActivity: LiveActivity?

    /// True while the wings show a second line of detail under them, which
    /// happens briefly when an activity arrives.
    @Published var isPeeking: Bool = false

    /// Resting size of the overlay for the current screen. The window
    /// controller sets this after measuring the active display.
    @Published var collapsedSize = CGSize(
        width: ScreenMetrics.defaultPillWidth,
        height: ScreenMetrics.fallbackPillHeight)

    /// Minimum width the overlay opens to, regardless of the collapsed size.
    static let expandedMinWidth: CGFloat = 440
    /// Height of the open body below the header row. The header row is as tall
    /// as the resting overlay, so its items sit beside the notch.
    static let expandedBodyHeight: CGFloat = 148
    /// Height reserved at the bottom of the open island for the tab bar.
    static let tabBarHeight: CGFloat = 36

    /// Width of each wing the resting overlay grows on either side to show a
    /// live activity.
    static let wingWidth: CGFloat = 48
    /// Height of the detail line the wings grow while peeking.
    static let peekRowHeight: CGFloat = 26

    /// Resting width of the media wing on a screen without a notch: a compact
    /// pill holding the cover and the equalizer.
    static let mediaRestingWidth: CGFloat = 170
    /// Width added to each side of the collapsed overlay for the media wing on a
    /// notched screen, so the cover and equalizer sit beside the notch.
    static let mediaWing: CGFloat = 66

    /// Extra height below the resting overlay that still counts as hovering it,
    /// so the pointer can reach it from just under the notch.
    static let hoverMargin: CGFloat = 12
    /// A little grow applied to the resting overlay while the pointer is over
    /// it. Mostly wider, only a touch taller so peek stays within the top strip
    /// and does not reach into app windows.
    static let peekGrow = CGSize(width: 16, height: 3)

    /// Size of the overlay when fully open for a given resting size.
    static func expandedSize(collapsed: CGSize) -> CGSize {
        CGSize(
            width: max(collapsed.width, expandedMinWidth),
            height: collapsed.height + expandedBodyHeight + tabBarHeight)
    }

    /// Size of the overlay when fully open.
    var expandedSize: CGSize {
        Self.expandedSize(collapsed: collapsedSize)
    }

    /// The media wing's own resting width, independent of whatever is currently
    /// showing. Used to hold the media content at a steady width so it fades in
    /// place rather than sliding when a live activity swaps in or out over it.
    var mediaWingWidth: CGFloat {
        hasNotch ? collapsedSize.width + Self.mediaWing * 2 : Self.mediaRestingWidth
    }

    /// True while the resting island shows the next calendar event (when idle
    /// and the option is on). Drives the resting size.
    @Published var eventRestingActive: Bool = false

    /// True while a timer is running and shown in the wings. Drives the resting
    /// size, just under a playing track.
    @Published var timerRestingActive: Bool = false

    /// True while a stopwatch is running and shown in the wings. Drives the
    /// resting size, just under the timer.
    @Published var stopwatchRestingActive: Bool = false

    /// True while the resting island shows the weather (idle, no event, and the
    /// option is on). Drives the resting size.
    @Published var weatherRestingActive: Bool = false

    /// Whether hovering grows the island a touch (the quick peek). Set from the
    /// person's setting.
    @Published var peekOnHover: Bool = true

    /// Resting size: a live activity takes over the wings while it is present
    /// (even over a playing track, briefly), then the media wing while a track
    /// is on, then the next-event wing when idle, and the bare pill otherwise.
    var restingSize: CGSize {
        if liveActivity != nil {
            return CGSize(
                width: collapsedSize.width + Self.wingWidth * 2,
                height: collapsedSize.height + (isPeeking ? Self.peekRowHeight : 0))
        }
        if nowPlayingActive {
            let width = hasNotch
                ? collapsedSize.width + Self.mediaWing * 2
                : Self.mediaRestingWidth
            return CGSize(width: width, height: collapsedSize.height)
        }
        if timerRestingActive || stopwatchRestingActive {
            return CGSize(
                width: collapsedSize.width + Self.wingWidth * 2,
                height: collapsedSize.height)
        }
        if eventRestingActive || weatherRestingActive {
            return CGSize(
                width: collapsedSize.width + Self.wingWidth * 2,
                height: collapsedSize.height)
        }
        return collapsedSize
    }

    /// Resting size grown by the small peek amount.
    var peekedSize: CGSize {
        CGSize(
            width: restingSize.width + Self.peekGrow.width,
            height: restingSize.height + Self.peekGrow.height)
    }

    /// The size the silhouette is drawn at right now. While resting it is the
    /// resting size, growing to the peek size on hover or while announcing a
    /// track; while open it is the open size.
    var visibleSize: CGSize {
        switch phase {
        case .expanded:
            return expandedSize
        case .collapsed:
            let base = (isHovering && peekOnHover) ? peekedSize : restingSize
            guard announcingTitle != nil else { return base }
            // Grow downward into one taller box for the announcement band.
            return CGSize(width: base.width, height: base.height + announcementBannerHeight)
        }
    }

    /// The area that senses hover and receives clicks. While resting it reaches
    /// a little below the overlay so it is easy to trigger; while open it
    /// matches the open overlay.
    var hitSize: CGSize {
        switch phase {
        case .expanded:
            return expandedSize
        case .collapsed:
            return CGSize(
                width: max(restingSize.width + Self.peekGrow.width, visibleSize.width),
                height: visibleSize.height + Self.hoverMargin)
        }
    }

    /// Resting size of the overlay for the current phase, ignoring hover. Used
    /// where only the phase matters.
    var targetSize: CGSize {
        phase == .expanded ? expandedSize : restingSize
    }
}
