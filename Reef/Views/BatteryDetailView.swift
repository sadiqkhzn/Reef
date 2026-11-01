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
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.32), tint.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header
                    .frame(height: headerHeight)
                content
            }
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
                    .font(ReefTheme.Typography.title)
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
        .islandCard(padding: ReefTheme.Spacing.l)
        .padding(.horizontal, ReefTheme.Radius.islandInset)
        .padding(.bottom, ReefTheme.Radius.islandInset)
    }

    private var ring: some View {
        RingGauge(progress: Double(snapshot.percent) / 100, tint: tint, lineWidth: 6)
            .frame(width: 64, height: 64)
            .overlay {
                VStack(spacing: 0) {
                    if snapshot.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(tint)
                    }
                    Text("\(snapshot.percent)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ReefTheme.Ink.primary)
                }
            }
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
