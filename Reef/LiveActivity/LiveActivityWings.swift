import SwiftUI

/// The resting island with its wings spread for a live activity.
///
/// The leading wing carries a glyph and the trailing wing a value. The middle
/// is left empty where the hardware notch is; on a screen without one it shows
/// a short label instead, so the pill does not read as a gap. While peeking, a
/// line of detail sits under the wings.
struct LiveActivityWings: View {
    var activity: LiveActivity
    /// Width of the middle region, which matches the notch or the resting pill.
    var centerWidth: CGFloat
    /// Height of the wing row, which matches the resting island.
    var rowHeight: CGFloat
    var showsLabel: Bool
    var isPeeking: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leading
                    .frame(width: NotchState.wingWidth)
                center
                    .frame(width: centerWidth)
                trailing
                    .frame(width: NotchState.wingWidth)
            }
            .frame(height: rowHeight)

            if isPeeking {
                Text(activity.detail)
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(ReefTheme.Ink.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, ReefTheme.Spacing.l)
                    .frame(height: NotchState.peekRowHeight)
                    .transition(.islandContent)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(activity.accessibilityLabel)
    }

    private var tint: Color {
        switch activity {
        case .charging, .fullyCharged:
            return ReefTheme.Status.charging
        case .lowBattery(_, let isCritical):
            return isCritical ? ReefTheme.Status.critical : ReefTheme.Status.warning
        case .deviceConnected:
            return ReefTheme.Status.charging
        case .deviceDisconnected:
            return ReefTheme.Ink.secondary
        case .audioOutput:
            return ReefTheme.Ink.primary
        }
    }

    @ViewBuilder
    private var leading: some View {
        switch activity {
        case .charging:
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, options: .repeating)
        case .fullyCharged:
            Image(systemName: "battery.100percent")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
        case .lowBattery(_, let isCritical):
            Image(systemName: isCritical ? "battery.0percent" : "battery.25percent")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, options: .repeating, isActive: isCritical)
        case .deviceConnected(_, let kind, _):
            Image(systemName: kind.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ReefTheme.Ink.primary)
        case .deviceDisconnected(_, let kind):
            Image(systemName: kind.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ReefTheme.Ink.secondary)
        case .audioOutput(_, let kind):
            Image(systemName: kind.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ReefTheme.Ink.primary)
        }
    }

    @ViewBuilder
    private var center: some View {
        if showsLabel {
            Text(activity.label)
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
        switch activity {
        case .charging(let percent), .lowBattery(let percent, _):
            Text("\(percent)%")
                .font(ReefTheme.Typography.wing)
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        case .deviceConnected(_, _, let battery):
            if let battery {
                Text("\(battery)%")
                    .font(ReefTheme.Typography.wing)
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
        case .fullyCharged:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
        case .deviceDisconnected:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
        case .audioOutput:
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
        }
    }
}
