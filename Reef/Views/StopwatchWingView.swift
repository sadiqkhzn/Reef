import SwiftUI

/// The resting island while a stopwatch runs: a stopwatch glyph on the leading
/// wing and the elapsed time on the trailing wing. On a screen without a notch
/// it shows a short label in the middle.
struct StopwatchWingView: View {
    @ObservedObject var stopwatch: StopwatchController
    var accent: Color
    /// Width of the middle region, matching the notch or resting pill.
    var centerWidth: CGFloat
    /// Height of the wing row, matching the resting island.
    var rowHeight: CGFloat
    var showsLabel: Bool

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "stopwatch")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: NotchState.wingWidth)
            center
                .frame(width: centerWidth)
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                Text(StopwatchController.shortLabel(stopwatch.elapsed))
                    .font(ReefTheme.Typography.wing)
                    .monospacedDigit()
                    .foregroundStyle(
                        stopwatch.isRunning ? ReefTheme.Ink.primary : ReefTheme.Ink.secondary)
            }
            .frame(width: NotchState.wingWidth)
        }
        .frame(height: rowHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stopwatch, \(StopwatchController.shortLabel(stopwatch.elapsed))")
    }

    @ViewBuilder
    private var center: some View {
        if showsLabel {
            Text("Stopwatch")
                .font(ReefTheme.Typography.caption)
                .foregroundStyle(ReefTheme.Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } else {
            Color.clear
        }
    }
}
