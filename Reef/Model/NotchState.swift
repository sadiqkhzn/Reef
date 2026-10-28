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

    /// Resting size of the overlay for the current screen. The window
    /// controller sets this after measuring the active display.
    @Published var collapsedSize: CGSize = ScreenMetrics.defaultPillSize

    /// Minimum width the overlay opens to, regardless of the collapsed size.
    static let expandedMinWidth: CGFloat = 380
    /// Height the overlay opens to.
    static let expandedHeight: CGFloat = 180

    /// Target size of the whole overlay for the current phase.
    var targetSize: CGSize {
        switch phase {
        case .collapsed:
            return collapsedSize
        case .expanded:
            return CGSize(
                width: max(collapsedSize.width, Self.expandedMinWidth),
                height: Self.expandedHeight)
        }
    }
}
