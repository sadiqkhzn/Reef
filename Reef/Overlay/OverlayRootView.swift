import SwiftUI

/// The SwiftUI root hosted inside the overlay panel.
///
/// The panel never changes size. This view draws the silhouette at the size the
/// current phase calls for, anchored to the top center, and animates between the
/// states. Resting on it grows it a touch at once, then it opens fully after a
/// short pause handled by the window controller. Hover is sensed over a slightly
/// larger area so the overlay is easy to reach from just under the notch.
struct OverlayRootView: View {
    @EnvironmentObject private var state: NotchState
    @StateObject private var battery = BatteryModel()

    private var shape: NotchShape {
        switch OverlayStyle.current {
        case .attached:
            return NotchShape(
                topCornerRadius: 6,
                bottomCornerRadius: state.phase == .expanded ? 20 : 13)
        case .floating:
            // Equal radii give a uniformly rounded bubble. At rest it is a
            // capsule; open it is a softly rounded panel.
            let radius: CGFloat = state.phase == .expanded ? 24 : state.visibleSize.height / 2
            return NotchShape(topCornerRadius: radius, bottomCornerRadius: radius)
        }
    }

    /// Open and close use a critically damped spring so there is no bounce, with
    /// the close a touch slower than the open.
    private var sizeAnimation: Animation {
        state.phase == .expanded
            ? .spring(response: 0.42, dampingFraction: 1.0)
            : .spring(response: 0.45, dampingFraction: 1.0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            OverlayBackground(shape: shape)
                .frame(width: state.visibleSize.width, height: state.visibleSize.height)
                .shadow(
                    color: .black.opacity(OverlayStyle.current.hasShadow ? 0.28 : 0),
                    radius: 3,
                    y: 0)

            if state.phase == .expanded {
                ExpandedView(battery: battery.snapshot)
                    .frame(width: state.visibleSize.width, height: state.visibleSize.height)
                    .transition(.opacity)
            }
        }
        .frame(width: state.hitSize.width, height: state.hitSize.height, alignment: .top)
        .contentShape(Rectangle())
        .onHover { hovering in
            state.isHovering = hovering
        }
        .animation(sizeAnimation, value: state.phase)
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: state.isHovering)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Hopping to another screen: shrink and fade out, then pop back in on the
        // new screen rather than teleporting.
        .scaleEffect(state.isRelocating ? 0.9 : 1, anchor: .top)
        .opacity(state.isRelocating ? 0 : 1)
        .animation(
            state.isRelocating
                ? .easeIn(duration: 0.12)
                : .spring(response: 0.34, dampingFraction: 0.78),
            value: state.isRelocating)
    }
}
