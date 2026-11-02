import AppKit
import SwiftUI

/// The resting island's brand mark: the user's image, centered in the pill on a
/// notch-free screen, or tucked into the leading wing beside the physical notch.
struct BrandWingView: View {
    let image: NSImage
    /// The notch/pill width to leave clear in the center when notched.
    let centerWidth: CGFloat
    let rowHeight: CGFloat
    let notched: Bool
    let opacity: Double
    let tinted: Bool
    let size: BrandImageSize
    /// Grows the mark a touch while the island is peeking on hover.
    var peeking: Bool = false

    private var targetHeight: CGFloat {
        max(12, (rowHeight - 6) * size.scale)
    }

    var body: some View {
        Group {
            if notched {
                HStack(spacing: 0) {
                    logo.frame(width: NotchState.wingWidth)
                    // Leave the camera housing and the opposite wing clear.
                    Color.clear.frame(width: centerWidth)
                    Color.clear.frame(width: NotchState.wingWidth)
                }
            } else {
                logo.frame(maxWidth: .infinity)
            }
        }
        .frame(height: rowHeight)
        .allowsHitTesting(false)
    }

    private var logo: some View {
        Image(nsImage: image)
            .renderingMode(tinted ? .template : .original)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: targetHeight)
            .foregroundStyle(ReefTheme.Ink.primary)
            .padding(.horizontal, 6)
            .opacity(opacity)
            // Lift slightly while the island peeks, so the mark feels alive rather
            // than stuck.
            .scaleEffect(peeking ? 1.08 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: peeking)
    }
}
