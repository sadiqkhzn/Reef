import SwiftUI

/// The open island's home page.
///
/// A header row runs beside the notch at the same height as the resting
/// island, with the page pill on the left and a compact battery reading on the
/// right. Below it, two cards: the time and date, and the battery in detail.
/// On a Mac with no battery, the time card takes the full width.
struct IslandHomeView: View {
    var battery: BatterySnapshot
    var accent: Color
    /// Height of the header row, matching the resting island.
    var headerHeight: CGFloat
    /// Space left clear in the middle of the header for the hardware notch.
    var notchWidth: CGFloat
    /// The next calendar event to glance at, when there is one.
    var nextEvent: CalendarEvent? = nil
    /// True when a track is playing, so the home page can offer a way back to
    /// the player.
    var canOpenPlayer: Bool = false
    /// Switch the open island to the player page.
    var onOpenPlayer: () -> Void = {}

    private let inset = ReefTheme.Radius.islandInset

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: headerHeight)

            HStack(spacing: ReefTheme.Spacing.s) {
                clockCard
                if battery.isPresent {
                    batteryCard
                        .frame(width: 168)
                }
            }
            .padding(.horizontal, inset)
            .padding(.top, 6)
            .padding(.bottom, inset)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            if canOpenPlayer {
                // A track is playing: offer a tap back to the player page.
                Button(action: onOpenPlayer) {
                    pill(title: "Now Playing", symbol: "music.note")
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                pill(title: "Home", symbol: "house.fill")
            }
            Spacer(minLength: notchWidth + ReefTheme.Spacing.l)
            if battery.isPresent {
                BatteryBadge(snapshot: battery)
            }
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
    }

    /// The page pill. Shows the current page, and on the home page becomes a
    /// button to the player while a track is on.
    private func pill(title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .font(ReefTheme.Typography.caption)
            .foregroundStyle(accent)
            .padding(.horizontal, ReefTheme.Spacing.s)
            .padding(.vertical, 3)
            .background(Capsule().fill(accent.opacity(0.18)))
    }

    // MARK: - Cards

    private var clockCard: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 2) {
                Spacer(minLength: 0)
                Text(context.date, format: .dateTime.hour().minute())
                    .font(ReefTheme.Typography.display)
                    .foregroundStyle(ReefTheme.Ink.primary)
                    .contentTransition(.numericText())
                Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(ReefTheme.Ink.secondary)
                if let event = nextEvent {
                    eventLine(event, now: context.date)
                        .padding(.top, 3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .islandCard(padding: ReefTheme.Spacing.l)
    }

    /// A one-line glance at the next event: a dot in its calendar color, the
    /// title, and a live countdown.
    private func eventLine(_ event: CalendarEvent, now: Date) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(event.colorHex.flatMap(Color.init(hex:)) ?? accent)
                .frame(width: 6, height: 6)
            Text(event.title)
                .foregroundStyle(ReefTheme.Ink.primary)
                .lineLimit(1)
            Text(event.countdownText(now: now))
                .foregroundStyle(ReefTheme.Ink.secondary)
                .lineLimit(1)
        }
        .font(ReefTheme.Typography.caption)
    }

    private var batteryTint: Color {
        switch battery.status {
        case .charging, .fullyCharged:
            return ReefTheme.Status.charging
        case .notCharging, .onBattery:
            if battery.percent <= BatteryActivityPolicy.criticalThreshold {
                return ReefTheme.Status.critical
            }
            if battery.percent <= BatteryActivityPolicy.lowThreshold {
                return ReefTheme.Status.warning
            }
            return accent
        }
    }

    private var batteryCard: some View {
        HStack(spacing: ReefTheme.Spacing.m) {
            RingGauge(progress: Double(battery.percent) / 100, tint: batteryTint, lineWidth: 6)
                .frame(width: 58, height: 58)
                .overlay {
                    Image(systemName: battery.isCharging ? "bolt.fill" : "battery.75percent")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(batteryTint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(battery.percent)%")
                    .font(ReefTheme.Typography.title)
                    .monospacedDigit()
                    .foregroundStyle(ReefTheme.Ink.primary)
                    .contentTransition(.numericText())
                Text(battery.status.title)
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(ReefTheme.Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .islandCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery \(battery.percent) percent, \(battery.status.title)")
    }
}
