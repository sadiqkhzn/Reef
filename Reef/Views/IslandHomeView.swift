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
    /// Hide the battery number, showing only the ring and glyph.
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
    /// Connected Bluetooth devices that report a battery level, for the cluster.
    @State private var devices: [DeviceBattery] = []

    /// Inset from the island's rounded edge for the cards, wide enough that they
    /// do not crowd the corners.
    private let inset: CGFloat = 10

    /// Top clearance: the full header height to clear the notch in the attached
    /// style, or a small inset when floating.
    private var topInset: CGFloat {
        notchWidth > 0 ? headerHeight : ReefTheme.Spacing.s
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)

            HStack(alignment: .top, spacing: ReefTheme.Spacing.s) {
                clockCard
                    .frame(maxHeight: .infinity)
                if !batteryItems.isEmpty {
                    batteryCluster
                        .frame(maxHeight: .infinity)
                        .frame(width: 150)
                }
            }
            .padding(.horizontal, inset)
            .padding(.bottom, 14)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    // MARK: - Controls

    private func headerButton(
        _ symbol: String, tint: Color, help: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
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
            VStack(alignment: .leading, spacing: 0) {
                // Top: date on the left, utility controls on the right.
                HStack(spacing: ReefTheme.Spacing.s) {
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ReefTheme.Ink.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let focus {
                        statusChip(symbol: focus.symbol, tint: accent, help: "Focus · \(focus.name)")
                    }
                    headerButton(
                        isAwake ? "cup.and.saucer.fill" : "cup.and.saucer",
                        tint: isAwake ? accent : ReefTheme.Ink.secondary,
                        help: isAwake ? "Keeping the Mac awake" : "Keep the Mac awake",
                        action: onToggleAwake)
                    headerButton(
                        "gearshape",
                        tint: ReefTheme.Ink.secondary,
                        help: "Open Reef settings",
                        action: onOpenSettings)
                }

                Spacer(minLength: ReefTheme.Spacing.s)

                Text(context.date, format: .dateTime.hour().minute())
                    .font(ReefTheme.Typography.display)
                    .monospacedDigit()
                    .foregroundStyle(ReefTheme.Ink.primary)
                    .contentTransition(.numericText())

                Spacer(minLength: ReefTheme.Spacing.s)

                // Bottom glance well.
                VStack(alignment: .leading, spacing: 4) {
                    if let event = nextEvent {
                        eventLine(event, now: context.date)
                    }
                    if let weather {
                        weatherLine(weather)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .islandCard(padding: ReefTheme.Spacing.m)
    }

    /// A one-line glance at the next event: a dot in its calendar color, the
    /// title, and a live countdown. Taps through to the agenda.
    private func eventLine(_ event: CalendarEvent, now: Date) -> some View {
        Button(action: onOpenCalendar) {
            HStack(spacing: ReefTheme.Spacing.s) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(event.colorHex.flatMap(Color.init(hex:)) ?? accent)
                    .frame(width: 3, height: 12)
                Text(event.title)
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(ReefTheme.Ink.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(event.countdownText(now: now))
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(ReefTheme.Ink.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.white.opacity(0.08)))
                    .lineLimit(1)
            }
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

    // MARK: - Battery cluster

    /// One battery source shown as a ring: the Mac and each connected device.
    private struct BatteryItem: Identifiable {
        let id: String
        let percent: Int
        let isCharging: Bool
        let symbol: String
    }

    /// The Mac plus connected devices that report a level, capped at four so the
    /// cluster stays a clean one-to-four grid.
    private var batteryItems: [BatteryItem] {
        var items: [BatteryItem] = []
        if battery.isPresent {
            items.append(BatteryItem(
                id: "mac", percent: battery.percent,
                isCharging: battery.isCharging, symbol: "laptopcomputer"))
        }
        for device in devices {
            if let overall = device.overall {
                items.append(BatteryItem(
                    id: device.name, percent: overall,
                    isCharging: false, symbol: device.kind.symbol))
            }
        }
        return Array(items.prefix(4))
    }

    /// The cluster: one big ring for a single source, a side-by-side pair for
    /// two, or a 2×2 grid for three or four. Each ring shrinks as more appear.
    @ViewBuilder
    private var batteryCluster: some View {
        let items = batteryItems
        Group {
            switch items.count {
            case 1:
                ring(items[0], size: 62, numberSize: 19, glyphSize: 12)
            case 2:
                HStack(spacing: ReefTheme.Spacing.s) {
                    ForEach(items) { ring($0, size: 52, numberSize: 15, glyphSize: 10) }
                }
            default:
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: ReefTheme.Spacing.s),
                        GridItem(.flexible(), spacing: ReefTheme.Spacing.s),
                    ],
                    spacing: ReefTheme.Spacing.s) {
                    ForEach(items) { ring($0, size: 44, numberSize: 13, glyphSize: 9) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .islandCard()
        .onAppear(perform: refreshDevices)
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            refreshDevices()
        }
    }

    private func ring(
        _ item: BatteryItem, size: CGFloat, numberSize: CGFloat, glyphSize: CGFloat
    ) -> some View {
        let tint = ringTint(for: item)
        return RingGauge(
            progress: Double(item.percent) / 100, tint: tint, lineWidth: size > 50 ? 5 : 4)
            .frame(width: size, height: size)
            .overlay {
                VStack(spacing: 1) {
                    Image(systemName: item.isCharging ? "bolt.fill" : item.symbol)
                        .font(.system(size: glyphSize, weight: .semibold))
                        .foregroundStyle(tint)
                    if !hidesBatteryPercentage {
                        Text("\(item.percent)")
                            .font(.system(size: numberSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(ReefTheme.Ink.primary)
                    }
                }
            }
    }

    /// Ring color: charging green wins, then Low Power Mode paints the Mac ring
    /// yellow (so it reads as power-saver without a separate badge), then the
    /// usual low/critical levels.
    private func ringTint(for item: BatteryItem) -> Color {
        if item.isCharging { return ReefTheme.Status.charging }
        if item.id == "mac" && lowPower { return ReefTheme.Status.warning }
        return batteryTint(item.percent, charging: false)
    }

    private func batteryTint(_ percent: Int, charging: Bool) -> Color {
        if charging { return ReefTheme.Status.charging }
        if percent <= BatteryActivityPolicy.criticalThreshold { return ReefTheme.Status.critical }
        if percent <= BatteryActivityPolicy.lowThreshold { return ReefTheme.Status.warning }
        return accent
    }

    private func refreshDevices() {
        devices = BluetoothBatteryReader.all()
    }
}
