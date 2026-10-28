import AppKit

/// The panel's content view.
///
/// The panel is kept at a fixed size that is large enough for the open overlay,
/// but most of it is transparent. This view makes those transparent areas click
/// through, so the desktop and the apps underneath stay usable. Only the region
/// the overlay actually occupies receives mouse events.
final class OverlayContainerView: NSView {

    /// The area, in this view's own coordinates, that should receive clicks.
    /// Everything outside it falls through to whatever is behind the panel.
    var interactiveRect: CGRect = .zero

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard interactiveRect.contains(local) else { return nil }
        return super.hitTest(point)
    }
}
