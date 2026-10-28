import SwiftUI

/// The silhouette of the overlay.
///
/// Two forms share one shape so the overlay can animate between them:
///
/// - With `shoulder` at zero, the top corners are convex with
///   `topCornerRadius`, which gives the floating bubble its uniformly rounded
///   look.
/// - With `shoulder` above zero, the top corners turn concave and flare out
///   along the top edge, the way the hardware notch flows out of the menu bar.
///   The body then sits `shoulder` points in from each side of the rect, so the
///   rect should be drawn that much wider on each side.
///
/// The bottom corners are rounded with `bottomCornerRadius` in both forms. All
/// three values are animatable, so the shape eases open as the overlay grows.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat
    var shoulder: CGFloat

    init(topCornerRadius: CGFloat = 6, bottomCornerRadius: CGFloat = 13, shoulder: CGFloat = 0) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
        self.shoulder = shoulder
    }

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(topCornerRadius, bottomCornerRadius), shoulder) }
        set {
            topCornerRadius = newValue.first.first
            bottomCornerRadius = newValue.first.second
            shoulder = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        shoulder > 0 ? flaredPath(in: rect) : roundedPath(in: rect)
    }

    /// Convex top corners: a plain rounded rectangle with separate top and
    /// bottom radii.
    private func roundedPath(in rect: CGRect) -> Path {
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

    /// Concave top corners that flare out along the top edge.
    private func flaredPath(in rect: CGRect) -> Path {
        let flare = min(shoulder, rect.width / 4, rect.height / 2)
        let left = rect.minX + flare
        let right = rect.maxX - flare
        let bottom = min(bottomCornerRadius, (right - left) / 2, rect.height - flare)

        var path = Path()
        // Start at the top-left tip of the flare.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Left shoulder curving down into the body.
        path.addQuadCurve(
            to: CGPoint(x: left, y: rect.minY + flare),
            control: CGPoint(x: left, y: rect.minY))
        // Left edge down.
        path.addLine(to: CGPoint(x: left, y: rect.maxY - bottom))
        // Bottom-left corner.
        path.addQuadCurve(
            to: CGPoint(x: left + bottom, y: rect.maxY),
            control: CGPoint(x: left, y: rect.maxY))
        // Bottom edge, left to right.
        path.addLine(to: CGPoint(x: right - bottom, y: rect.maxY))
        // Bottom-right corner.
        path.addQuadCurve(
            to: CGPoint(x: right, y: rect.maxY - bottom),
            control: CGPoint(x: right, y: rect.maxY))
        // Right edge up.
        path.addLine(to: CGPoint(x: right, y: rect.minY + flare))
        // Right shoulder curving out to the top-right tip.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: right, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
