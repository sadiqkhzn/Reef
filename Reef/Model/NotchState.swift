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

    /// The live activity shown in the wings while resting, if any.
    @Published var liveActivity: LiveActivity?

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

    /// Extra height below the resting overlay that still counts as hovering it,
    /// so the pointer can reach it from just under the notch.
    static let hoverMargin: CGFloat = 12
    /// A little grow applied to the resting overlay while the pointer is over
    /// it, before it opens fully. This is the quick acknowledgement of hover.
    static let peekGrow = CGSize(width: 10, height: 5)

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

    /// Resting size including the wings while a live activity shows.
    var restingSize: CGSize {
        guard liveActivity != nil else { return collapsedSize }
        return CGSize(
            width: collapsedSize.width + Self.wingWidth * 2,
            height: collapsedSize.height)
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
