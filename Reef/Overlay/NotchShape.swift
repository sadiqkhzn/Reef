import SwiftUI

/// The silhouette of the overlay.
///
/// The top corners carry a small radius so the shape sits almost flush with the
/// top edge of the screen, blending into the physical notch. The bottom corners
/// are rounded more generously so the body reads as a soft pill. Both radii are
/// animatable, which lets the shape ease open as the overlay grows.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    init(topCornerRadius: CGFloat = 6, bottomCornerRadius: CGFloat = 13) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let half = min(rect.width, rect.height) / 2
        let top = min(topCornerRadius, half)
        let bottom = min(bottomCornerRadius, half)

        var path = Path()
        // Top edge, left to right.
        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        // Top-right corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + top),
            control: CGPoint(x: rect.maxX, y: rect.minY))
        // Right edge down.
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        // Bottom-right corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottom, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY))
        // Bottom edge, right to left.
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        // Bottom-left corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottom),
            control: CGPoint(x: rect.minX, y: rect.maxY))
        // Left edge up.
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
        // Top-left corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
