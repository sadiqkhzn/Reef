import SwiftUI

/// A small battery glyph with a fill that tracks the charge, plus a bolt while
/// charging. Drawn by hand so the fill and color read clearly at small sizes.
struct BatteryBadge: View {
    var snapshot: BatterySnapshot

    private var fillColor: Color {
        if snapshot.isCharging || snapshot.isPluggedIn { return .green }
        switch snapshot.percent {
        case ...10: return .red
        case ...20: return .yellow
        default: return .white
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("\(snapshot.percent)%")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            body(width: 26, height: 13)
        }
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
