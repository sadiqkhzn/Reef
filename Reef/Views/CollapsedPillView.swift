import SwiftUI

/// The resting face of the overlay.
///
/// At rest the overlay is a slim bar the size of the notch. The things that
/// will live here later (a now playing glyph, small status dots) are not here
/// yet, so for now this view only reserves the correct area and keeps the whole
/// bar responsive to the pointer. Keeping it as its own view means the resting
/// content has an obvious home to grow into.
struct CollapsedPillView: View {
    @EnvironmentObject private var state: NotchState

    var body: some View {
        Color.clear
            .frame(width: state.collapsedSize.width, height: state.collapsedSize.height)
            .contentShape(Rectangle())
    }
}
