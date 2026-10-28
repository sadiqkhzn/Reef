import SwiftUI

/// The SwiftUI root hosted inside the overlay panel.
///
/// It draws the silhouette and lays the current phase's content on top. The
/// pointer tracking here feeds `NotchState.isHovering`, which later versions use
/// to open the overlay.
struct OverlayRootView: View {
    @EnvironmentObject private var state: NotchState

    private var shape: NotchShape {
        NotchShape(
            topCornerRadius: 6,
            bottomCornerRadius: state.phase == .expanded ? 20 : 13)
    }

    var body: some View {
        ZStack(alignment: .top) {
            OverlayBackground(shape: shape)

            CollapsedPillView()
        }
        .frame(
            width: state.targetSize.width,
            height: state.targetSize.height,
            alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onHover { hovering in
            state.isHovering = hovering
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: state.phase)
    }
}
