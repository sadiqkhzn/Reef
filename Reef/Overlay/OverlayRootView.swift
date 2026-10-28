import SwiftUI

/// The SwiftUI root hosted inside the overlay panel.
///
/// It draws the silhouette and lays the current phase's content on top. The
/// pointer tracking here feeds `NotchState.isHovering`; the window controller
/// turns that into an open or closed phase.
struct OverlayRootView: View {
    @EnvironmentObject private var state: NotchState
    @StateObject private var battery = BatteryModel()

    private var shape: NotchShape {
        NotchShape(
            topCornerRadius: 6,
            bottomCornerRadius: state.phase == .expanded ? 20 : 13)
    }

    var body: some View {
        ZStack(alignment: .top) {
            OverlayBackground(shape: shape)

            content
        }
        .frame(
            width: state.targetSize.width,
            height: state.targetSize.height,
            alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onHover { hovering in
            state.isHovering = hovering
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: state.phase)
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .expanded:
            ExpandedView(battery: battery.snapshot)
                .transition(.opacity.combined(with: .move(edge: .top)))
        case .collapsed:
            CollapsedPillView()
        }
    }
}
