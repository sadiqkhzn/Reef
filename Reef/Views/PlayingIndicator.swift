import SwiftUI

/// A small set of bars that bounce like an equalizer, used to show that music
/// is playing at a glance.
///
/// The motion is driven by a frame-based `TimelineView` rather than a
/// `repeatForever` animation, which keeps it from fighting other animations on
/// the overlay (that combination can stall the UI). When `active` is false the
/// bars hold still, so nothing animates during a screen hop.
struct PlayingIndicator: View {
    var color: Color = .white
    var barCount: Int = 4
    var active: Bool = true

    var body: some View {
        if active {
            TimelineView(.animation) { timeline in
                bars(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            bars(at: 0)
        }
    }

    private func bars(at time: TimeInterval) -> some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                let phase = time * 6 + Double(index) * 1.1
                let height = 4 + (sin(phase) * 0.5 + 0.5) * 9
                Capsule()
                    .fill(color)
                    .frame(width: 2.5, height: height)
            }
        }
        .frame(height: 14)
    }
}
