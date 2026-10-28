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
    static let expandedMinWidth: CGFloat = 400
    /// Height of the open body below the header row. The header row is as tall
    /// as the resting overlay, so its items sit beside the notch.
    static let expandedBodyHeight: CGFloat = 136

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
            height: collapsed.height + expandedBodyHeight)
    }

    /// Size of the overlay when fully open.
    var expandedSize: CGSize {
        Self.expandedSize(collapsed: collapsedSize)
    }

    /// Resting size including the media wing while a track is on, the live
    /// activity wings and their detail line otherwise. Media takes precedence.
    var restingSize: CGSize {
        if nowPlayingActive {
            let width = hasNotch
                ? collapsedSize.width + Self.mediaWing * 2
                : Self.mediaRestingWidth
            return CGSize(width: width, height: collapsedSize.height)
        }
        guard liveActivity != nil else { return collapsedSize }
        return CGSize(
            width: collapsedSize.width + Self.wingWidth * 2,
            height: collapsedSize.height + (isPeeking ? Self.peekRowHeight : 0))
    }

    /// The size the silhouette is drawn at right now. While resting it is the
    /// resting size, growing a touch on hover; while open it is the open size.
    var visibleSize: CGSize {
        switch phase {
        case .expanded:
            return expandedSize
        case .collapsed:
            guard isHovering else { return restingSize }
            return CGSize(
                width: restingSize.width + Self.peekGrow.width,
                height: restingSize.height + Self.peekGrow.height)
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
                width: restingSize.width + Self.peekGrow.width,
                height: restingSize.height + Self.hoverMargin)
        }
    }

    /// Resting size of the overlay for the current phase, ignoring hover. Used
    /// where only the phase matters.
    var targetSize: CGSize {
        phase == .expanded ? expandedSize : restingSize
    }
}
