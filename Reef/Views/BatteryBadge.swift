import SwiftUI

/// A small battery glyph with a fill that tracks the charge, plus a bolt while
/// charging. Drawn by hand so the fill and color read clearly at small sizes.
struct BatteryBadge: View {
    var snapshot: BatterySnapshot

    private var fillColor: Color {
        if snapshot.isCharging || snapshot.isPluggedIn { return ReefTheme.Status.charging }
        switch snapshot.percent {
        case ...BatteryActivityPolicy.criticalThreshold: return ReefTheme.Status.critical
        case ...BatteryActivityPolicy.lowThreshold: return ReefTheme.Status.warning
        default: return ReefTheme.Ink.primary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("\(snapshot.percent)%")
                .font(ReefTheme.Typography.wing)
                .foregroundStyle(ReefTheme.Ink.primary)
                .monospacedDigit()

            body(width: 24, height: 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery \(snapshot.percent) percent")
    }

    private func body(width: CGFloat, height: CGFloat) -> some View {
        let fraction = CGFloat(snapshot.percent) / 100
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3.5)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
                .frame(width: width, height: height)

            RoundedRectangle(cornerRadius: 2)
                .fill(fillColor)
                .frame(width: max(2, (width - 4) * fraction), height: height - 4)
                .padding(.leading, 2)

            if snapshot.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: width, height: height)
            }
        }
        .overlay(alignment: .trailing) {
            // The small terminal nub on the right of the battery.
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.55))
                .frame(width: 1.6, height: height * 0.45)
                .offset(x: 2.6)
        }
    }
}
