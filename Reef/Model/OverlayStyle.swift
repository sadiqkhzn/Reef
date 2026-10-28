import CoreGraphics

/// How the overlay sits on screen.
///
/// `attached` hugs the top edge: it blends with the notch, or sits in the menu
/// bar strip on Macs without one, and never covers app windows at rest.
/// `floating` detaches into a rounded bubble a little below the top edge, which
/// looks more like its own object at the cost of a light overlap at rest.
///
/// This will become a user setting. For now it is a single switch so the two
/// looks can be compared.
enum OverlayStyle {
    case attached
    case floating

    static let current: OverlayStyle = .floating

    /// Distance the overlay is pushed down from the top edge.
    var topGap: CGFloat {
        switch self {
        case .attached: return 0
        case .floating: return 3
        }
    }

    /// Whether the overlay carries a soft shadow to read as floating.
    var hasShadow: Bool {
        self == .floating
    }

    /// Resting pill size for the floating style. The attached style sizes itself
    /// to the notch or the menu bar instead.
    static let floatingRestingSize = CGSize(width: 200, height: 28)
}
