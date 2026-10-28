import SwiftUI

/// Fill behind the overlay content.
///
/// The base is solid black so the shape disappears into the physical notch on
/// MacBooks that have one. A faint material sits on top to give the body a hint
/// of depth where the pointer hovers. Newer systems get the glass material; on
/// older systems this quietly falls back to a thin material.
struct OverlayBackground: View {
    var shape: NotchShape

    var body: some View {
        shape
            .fill(Color.black)
            .overlay(highlight)
            .overlay(edge)
    }

    /// A soft top-down sheen so the body is not perfectly flat.
    private var highlight: some View {
        shape
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.clear],
                    startPoint: .top,
                    endPoint: .center))
    }

    /// A hairline edge that reads cleanly against bright wallpapers.
    private var edge: some View {
        shape
            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
    }
}
