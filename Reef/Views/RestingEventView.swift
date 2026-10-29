import SwiftUI

/// The next calendar event shown on the resting island while nothing is
/// playing. A calendar glyph sits in the leading wing and a compact countdown
/// in the trailing wing, with the notch left clear between them. On a Mac with
/// no notch the title fills the center.
struct RestingEventView: View {
    let event: CalendarEvent
    /// Width to leave clear in the middle for the notch.
    var centerWidth: CGFloat
    /// Height of the wing row, matching the resting island.
    var rowHeight: CGFloat
    var showsTitle: Bool
    /// Current time, passed in so the countdown stays live.
    var now: Date

    private var tint: Color {
        event.colorHex.flatMap(Color.init(hex:)) ?? ReefTheme.Ink.primary
    }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: NotchState.wingWidth)

            Group {
                if showsTitle {
                    Text(event.title)
                        .font(ReefTheme.Typography.caption)
                        .foregroundStyle(ReefTheme.Ink.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Color.clear
                }
            }
            .frame(width: centerWidth)

            Text(event.shortCountdownText(now: now))
                .font(ReefTheme.Typography.wing)
                .monospacedDigit()
                .foregroundStyle(ReefTheme.Ink.primary)
                .frame(width: NotchState.wingWidth)
        }
        .frame(height: rowHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next event, \(event.title), \(event.countdownText(now: now))")
    }
}
