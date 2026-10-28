import SwiftUI

/// Shared, observable state for the overlay.
///
/// Views read from it, and the window controller watches `phase` so it can
/// resize the panel when the overlay opens or closes.
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

    /// Resting size of the overlay for the current screen. The window
    /// controller sets this after measuring the active display.
    @Published var collapsedSize = CGSize(
        width: ScreenMetrics.defaultPillWidth,
        height: ScreenMetrics.fallbackPillHeight)

    /// Minimum width the overlay opens to, regardless of the collapsed size.
    static let expandedMinWidth: CGFloat = 380
    /// Height the overlay opens to.
    static let expandedHeight: CGFloat = 180

    /// Extra height below the resting overlay that still counts as hovering it,
    /// so the pointer can reach it from just under the notch.
    static let hoverMargin: CGFloat = 12
    /// A little grow applied to the resting overlay while the pointer is over
    /// it, before it opens fully. This is the quick acknowledgement of hover.
    static let peekGrow = CGSize(width: 10, height: 5)

    /// Size of the overlay when fully open.
    var expandedSize: CGSize {
        CGSize(
            width: max(collapsedSize.width, Self.expandedMinWidth),
            height: Self.expandedHeight)
    }

    /// The size the silhouette is drawn at right now. While resting it is the
    /// collapsed size, growing a touch on hover; while open it is the open size.
    var visibleSize: CGSize {
        switch phase {
        case .expanded:
            return expandedSize
        case .collapsed:
            guard isHovering else { return collapsedSize }
            return CGSize(
                width: collapsedSize.width + Self.peekGrow.width,
                height: collapsedSize.height + Self.peekGrow.height)
        }
    }

    /// The area that senses hover and receives clicks. While resting it reaches
    /// a little below the notch so it is easy to trigger; while open it matches
    /// the open overlay.
    var hitSize: CGSize {
        switch phase {
        case .expanded:
            return expandedSize
        case .collapsed:
            return CGSize(
                width: collapsedSize.width + Self.peekGrow.width,
                height: collapsedSize.height + Self.hoverMargin)
        }
    }

    /// Resting size of the overlay for the current phase, ignoring hover. Used
    /// where only the phase matters.
    var targetSize: CGSize {
        phase == .expanded ? expandedSize : collapsedSize
    }
}
