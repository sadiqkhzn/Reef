import CoreGraphics

/// Geometry for placing the Reef overlay.
///
/// Everything here is pure: it takes numbers in and gives frames out, with no
/// reference to AppKit or a live screen. That keeps the placement math unit
/// testable. The window controller feeds it values read from `NSScreen`.
enum ScreenMetrics {

    /// Describes the physical notch cutout on a screen.
    struct Notch: Equatable {
        /// True when the screen has a notch.
        var exists: Bool
        /// Width and height of the cutout. Zero when there is no notch.
        var size: CGSize
    }

    /// Width of the resting overlay on Macs that have no notch.
    static let defaultPillWidth: CGFloat = 190
    /// Resting height used when the menu bar height is not known.
    static let fallbackPillHeight: CGFloat = 24

    /// Width used for a notch when the system does not report the areas beside
    /// it. This is a sensible middle value across current notched MacBooks.
    static let fallbackNotchWidth: CGFloat = 200

    /// Work out the notch from a screen's safe area and the areas beside it.
    ///
    /// - Parameters:
    ///   - safeAreaTop: the screen's top safe area inset. Greater than zero on
    ///     notched Macs, zero otherwise.
    ///   - screenWidth: the full width of the screen.
    ///   - leftAreaWidth: width of the usable area to the left of the notch,
    ///     if the system reports it.
    ///   - rightAreaWidth: width of the usable area to the right of the notch,
    ///     if the system reports it.
    static func notch(safeAreaTop: CGFloat,
                      screenWidth: CGFloat,
                      leftAreaWidth: CGFloat?,
                      rightAreaWidth: CGFloat?) -> Notch {
        guard safeAreaTop > 0 else {
            return Notch(exists: false, size: .zero)
        }

        let width: CGFloat
        if let left = leftAreaWidth, let right = rightAreaWidth, left > 0, right > 0 {
            width = max(0, screenWidth - left - right)
        } else {
            width = fallbackNotchWidth
        }

        return Notch(exists: true, size: CGSize(width: width, height: safeAreaTop))
    }

    /// Size of the resting overlay.
    ///
    /// On a notched Mac it matches the notch. On a Mac without a notch it is a
    /// pill as tall as the menu bar, so when it is anchored to the top of the
    /// screen it sits inside the menu bar strip rather than over app windows.
    static func collapsedSize(for notch: Notch, menuBarHeight: CGFloat) -> CGSize {
        if notch.exists {
            return notch.size
        }
        let height = menuBarHeight > 0 ? menuBarHeight : fallbackPillHeight
        return CGSize(width: defaultPillWidth, height: height)
    }

    /// Frame for an overlay of `size`, centered along the top edge of a screen.
    ///
    /// Uses AppKit screen coordinates where the origin is the bottom left and y
    /// grows upward, so the top edge is `screenFrame.maxY`.
    ///
    /// - Parameter topInset: distance below the top edge. Used on Macs without a
    ///   notch so the pill does not sit flush against the menu bar.
    static func overlayFrame(screenFrame: CGRect,
                             size: CGSize,
                             topInset: CGFloat = 0) -> CGRect {
        let x = screenFrame.minX + (screenFrame.width - size.width) / 2
        let y = screenFrame.maxY - size.height - topInset
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
