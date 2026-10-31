import SwiftUI

/// The resting island while a timer runs: a shrinking ring on the leading wing
/// and the time left on the trailing wing. On a screen without a notch it shows
/// a short label in the middle so the pill does not read as a gap.
struct TimerWingView: View {
    @ObservedObject var timer: TimerController
    var accent: Color
    /// Width of the middle region, matching the notch or resting pill.
    var centerWidth: CGFloat
    /// Height of the wing row, matching the resting island.
    var rowHeight: CGFloat
    var showsLabel: Bool

    private var tint: Color { timer.isFinished ? ReefTheme.Status.warning : accent }

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: NotchState.wingWidth)
            center
                .frame(width: centerWidth)
            trailing
                .frame(width: NotchState.wingWidth)
        }
        .frame(height: rowHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            timer.isFinished
                ? "Timer finished"
                : "Timer, \(TimerController.label(timer.remaining)) left")
    }

    private var leading: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.25), lineWidth: 2)
            Circle()
                .trim(from: 0, to: 1 - timer.progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: timer.isFinished ? "bell.fill" : "timer")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, options: .repeating, isActive: timer.isFinished)
        }
        .frame(width: 17, height: 17)
    }

    @ViewBuilder
    private var center: some View {
        if showsLabel {
            Text(timer.isFinished ? "Done" : "Timer")
                .font(ReefTheme.Typography.caption)
                .foregroundStyle(ReefTheme.Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if timer.isFinished {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
        } else {
            Text(TimerController.label(timer.remaining))
                .font(ReefTheme.Typography.wing)
                .monospacedDigit()
                .foregroundStyle(timer.isRunning ? ReefTheme.Ink.primary : ReefTheme.Ink.secondary)
                .contentTransition(.numericText())
        }
    }
}
