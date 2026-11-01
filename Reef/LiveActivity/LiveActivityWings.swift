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
    /// How device activities draw their device.
    var deviceArtwork: DeviceArtwork = .symbols

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
        case .deviceLowBattery:
            return ReefTheme.Status.warning
        case .audioOutput:
            return ReefTheme.Ink.primary
        case .calendarEvent:
            return ReefTheme.Ink.primary
        case .lowPowerMode:
            return ReefTheme.Status.warning
        case .focus(_, _, let on):
            return on ? ReefTheme.Ink.primary : ReefTheme.Ink.secondary
        case .volume, .brightness:
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
            deviceGlyph(kind, tint: ReefTheme.Ink.primary)
        case .deviceDisconnected(_, let kind):
            deviceGlyph(kind, tint: ReefTheme.Ink.secondary)
                .opacity(0.6)
        case .deviceLowBattery(_, let kind, _):
            deviceGlyph(kind, tint: tint)
                .symbolEffect(.pulse, options: .repeating)
        case .audioOutput(_, let kind):
            Image(systemName: kind.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ReefTheme.Ink.primary)
        case .calendarEvent:
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ReefTheme.Ink.primary)
        case .lowPowerMode:
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
        case .focus(_, let symbol, let on):
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .opacity(on ? 1 : 0.7)
        case .volume(let level, let muted):
            Image(systemName: LiveActivity.volumeSymbol(level: level, muted: muted))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(muted ? ReefTheme.Ink.secondary : ReefTheme.Ink.primary)
                .contentTransition(.symbolEffect(.replace))
        case .brightness(let level):
            Image(systemName: LiveActivity.brightnessSymbol(level: level))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ReefTheme.Ink.primary)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    /// The device in the leading wing: its 3D model when one fits and models
    /// are chosen, otherwise its symbol.
    private func deviceGlyph(_ kind: DeviceKind, tint: Color) -> some View {
        DeviceGlyph(
            model: DeviceModel(kind: kind),
            symbol: kind.symbol,
            artwork: deviceArtwork,
            size: min(rowHeight - 6, 26),
            symbolSize: 14,
            tint: tint)
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
        case .deviceLowBattery(_, _, let percent):
            Text("\(percent)%")
                .font(ReefTheme.Typography.wing)
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        case .audioOutput:
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
        case .calendarEvent:
            Image(systemName: "clock")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
        case .lowPowerMode:
            Image(systemName: "leaf.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
        case .focus(_, _, let on):
            Image(systemName: on ? "checkmark" : "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
        case .volume(let level, _):
            LevelBar(value: level)
        case .brightness(let level):
            LevelBar(value: level)
        }
    }
}

/// A slim capsule that fills from the left to show a 0...1 level, used by the
/// volume and brightness HUDs in the trailing wing.
private struct LevelBar: View {
    var value: Double

    private var fraction: CGFloat { CGFloat(min(max(value, 0), 1)) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ReefTheme.Ink.primary.opacity(0.22))
                Capsule()
                    .fill(ReefTheme.Ink.primary)
                    .frame(width: max(3, geo.size.width * fraction))
            }
        }
        .frame(width: 32, height: 4)
        .animation(.easeOut(duration: 0.18), value: fraction)
    }
}
