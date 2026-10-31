import SwiftUI

/// The battery page of the open island: a large ring with the charge, the power
/// state, and a time-left estimate when the system has one.
struct BatteryDetailView: View {
    var snapshot: BatterySnapshot
    var accent: Color
    var headerHeight: CGFloat
    var notchWidth: CGFloat
    /// Leave the open island (back to home).
    var onClose: () -> Void

    private var tint: Color {
        if snapshot.isCharging || snapshot.isPluggedIn { return ReefTheme.Status.charging }
        switch snapshot.percent {
        case ...BatteryActivityPolicy.criticalThreshold: return ReefTheme.Status.critical
        case ...BatteryActivityPolicy.lowThreshold: return ReefTheme.Status.warning
        default: return accent
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: headerHeight)
            content
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button(action: onClose) {
                Label("Battery", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(accent)
                    .padding(.horizontal, ReefTheme.Spacing.s)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(accent.opacity(0.18)))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer(minLength: notchWidth + ReefTheme.Spacing.l)
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
    }

    private var content: some View {
        HStack(spacing: ReefTheme.Spacing.l) {
            ring
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.status.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ReefTheme.Ink.primary)
                if let estimate = snapshot.timeEstimateText {
                    Label(
                        snapshot.status == .charging
                            ? "\(estimate) to full"
                            : "\(estimate) left",
                        systemImage: snapshot.status == .charging ? "bolt.fill" : "clock")
                        .labelStyle(.titleAndIcon)
                        .font(ReefTheme.Typography.caption)
                        .foregroundStyle(ReefTheme.Ink.secondary)
                } else {
                    Text(powerSourceText)
                        .font(ReefTheme.Typography.caption)
                        .foregroundStyle(ReefTheme.Ink.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
        .padding(.vertical, 8)
        .frame(maxHeight: .infinity)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(snapshot.percent) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: snapshot.percent)
            VStack(spacing: 0) {
                if snapshot.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint)
                }
                Text("\(snapshot.percent)")
                    .font(.system(size: 20, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(ReefTheme.Ink.primary)
            }
        }
        .frame(width: 64, height: 64)
    }

    private var powerSourceText: String {
        switch snapshot.status {
        case .fullyCharged: return "On power adapter"
        case .notCharging: return "Holding charge"
        case .charging: return "Calculating time to full"
        case .onBattery: return "Calculating time left"
        }
    }
}
