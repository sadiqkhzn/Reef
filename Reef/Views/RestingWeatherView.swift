import SwiftUI

/// The current weather shown on the resting island when idle and there's no
/// next event. A condition glyph sits in the leading wing and the temperature
/// in the trailing wing, with the notch left clear between them. On a Mac with
/// no notch the condition label fills the center.
struct RestingWeatherView: View {
    let snapshot: WeatherSnapshot
    /// Width to leave clear in the middle for the notch.
    var centerWidth: CGFloat
    /// Height of the wing row, matching the resting island.
    var rowHeight: CGFloat
    var showsLabel: Bool

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: snapshot.condition.symbol)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.multicolor)
                .frame(width: NotchState.wingWidth)

            Group {
                if showsLabel {
                    Text(snapshot.condition.label)
                        .font(ReefTheme.Typography.caption)
                        .foregroundStyle(ReefTheme.Ink.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Color.clear
                }
            }
            .frame(width: centerWidth)

            Text(snapshot.temperatureText)
                .font(ReefTheme.Typography.wing)
                .monospacedDigit()
                .foregroundStyle(ReefTheme.Ink.primary)
                .frame(width: NotchState.wingWidth)
        }
        .frame(height: rowHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weather, \(snapshot.temperatureText), \(snapshot.condition.label)")
    }
}
