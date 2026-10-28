import SwiftUI

/// The open face of the overlay.
///
/// For now it shows the time and date on the left and the battery on the right.
/// As more sources arrive (media, nearby devices) this is where they will sit.
struct ExpandedView: View {
    var battery: BatterySnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            clock
            Spacer(minLength: 8)
            if battery.isPresent {
                BatteryBadge(snapshot: battery)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var clock: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 2) {
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}
