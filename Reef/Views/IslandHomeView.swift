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
    /// Local weather, shown when there is no event to show instead.
    var weather: WeatherSnapshot? = nil
    /// True when a track is playing, so the home page can offer a way back to
    /// the player.
    var canOpenPlayer: Bool = false
    /// Switch the open island to the player page.
    var onOpenPlayer: () -> Void = {}
    /// Number of files on the shelf, for a badge; zero hides the shelf button.
    var shelfCount: Int = 0
    /// Switch the open island to the shelf page.
    var onOpenShelf: () -> Void = {}
    /// Open the agenda page. The event line taps through to it.
    var onOpenCalendar: () -> Void = {}
    /// Open the timer page.
    var onOpenTimer: () -> Void = {}
    /// Open the weather forecast page. The weather line taps through to it.
    var onOpenWeather: () -> Void = {}
    /// Open the battery detail page. The battery badge taps through to it.
    var onOpenBattery: () -> Void = {}
    /// Hide the battery number, showing only the glyph and ring.
    var hidesBatteryPercentage: Bool = false
    /// The active macOS Focus, shown as a status chip when one is on.
    var focus: FocusStatus? = nil
    /// Whether keep-awake (caffeinate) is on, lighting its toggle.
    var isAwake: Bool = false
    /// Flip keep-awake from the header toggle.
    var onToggleAwake: () -> Void = {}
    /// Open the Settings window from the header gear.
    var onOpenSettings: () -> Void = {}

    /// Low Power Mode, read from the system and kept live by the notification.
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    /// Inset from the island's rounded edge for the cards, wide enough that they
    /// do not crowd the corners.
    private let inset: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: headerHeight)

            HStack(spacing: ReefTheme.Spacing.s) {
                clockCard
                if battery.isPresent {
                    batteryCard
                        .frame(width: 160)
                }
            }
            .padding(.horizontal, inset)
            .padding(.top, 4)
            .padding(.bottom, inset)
        }
    }

    // MARK: - Header

    private var header: some View {
        // The bottom tab bar labels the page, so the header is just the quick
        // controls on the left and the status cluster on the right.
        HStack(spacing: 0) {
            if shelfCount > 0 {
                Button(action: onOpenShelf) {
                    HStack(spacing: 3) {
                        Image(systemName: "tray.full")
                        Text("\(shelfCount)")
                    }
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(ReefTheme.Ink.secondary)
                    .padding(.leading, ReefTheme.Spacing.s)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open the shelf")
            }
            Button(action: onOpenCalendar) {
                Image(systemName: "calendar")
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(ReefTheme.Ink.secondary)
                    .padding(.leading, ReefTheme.Spacing.s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open the calendar")
            Button(action: onOpenTimer) {
                Image(systemName: "timer")
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(ReefTheme.Ink.secondary)
                    .padding(.leading, ReefTheme.Spacing.s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open the timer")
            Button(action: onToggleAwake) {
                Image(systemName: isAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(isAwake ? accent : ReefTheme.Ink.secondary)
                    .padding(.leading, ReefTheme.Spacing.s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isAwake ? "Keeping the Mac awake" : "Keep the Mac awake")
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(ReefTheme.Ink.secondary)
                    .padding(.leading, ReefTheme.Spacing.s)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open Reef settings")

            Spacer(minLength: notchWidth + ReefTheme.Spacing.l)

            statusCluster
            if battery.isPresent {
                Button(action: onOpenBattery) {
                    BatteryBadge(snapshot: battery, showsPercentage: !hidesBatteryPercentage)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Battery details")
            }
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
        .onReceive(NotificationCenter.default.publisher(
            for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    /// The right-wing status glance: the active Focus and Low Power Mode, each
    /// shown only while on. Quiet chips that sit just left of the battery badge.
    @ViewBuilder
    private var statusCluster: some View {
        HStack(spacing: 5) {
            if let focus {
                statusChip(symbol: focus.symbol, tint: accent, help: "Focus · \(focus.name)")
            }
            if lowPower {
                statusChip(symbol: "bolt.fill", tint: ReefTheme.Status.warning, help: "Low Power Mode")
            }
        }
        .padding(.trailing, focus != nil || lowPower ? ReefTheme.Spacing.s : 0)
    }

    private func statusChip(symbol: String, tint: Color, help: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 20, height: 20)
            .background(Circle().fill(tint.opacity(0.16)))
            .help(help)
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
                if let weather {
                    weatherLine(weather)
                        .padding(.top, 3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .islandCard(padding: ReefTheme.Spacing.l)
    }

    /// A one-line glance at the next event: a dot in its calendar color, the
    /// title, and a live countdown. Taps through to the agenda.
    private func eventLine(_ event: CalendarEvent, now: Date) -> some View {
        Button(action: onOpenCalendar) {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// A one-line glance at the weather: the condition symbol, the temperature,
    /// and the condition name. Taps through to the forecast page.
    private func weatherLine(_ weather: WeatherSnapshot) -> some View {
        Button(action: onOpenWeather) {
            HStack(spacing: 5) {
                Image(systemName: weather.condition.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(accent)
                Text(weather.temperatureText)
                    .foregroundStyle(ReefTheme.Ink.primary)
                Text(weather.condition.label)
                    .foregroundStyle(ReefTheme.Ink.secondary)
                    .lineLimit(1)
            }
            .font(ReefTheme.Typography.caption)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                if hidesBatteryPercentage {
                    // No number: the status reads as the main label instead.
                    Text(battery.status.title)
                        .font(ReefTheme.Typography.title)
                        .foregroundStyle(ReefTheme.Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                } else {
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
            }
            Spacer(minLength: 0)
        }
        .islandCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery \(battery.percent) percent, \(battery.status.title)")
    }
}
