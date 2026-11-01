import SwiftUI

/// Pure clock formatting for the ambient display, kept apart so it can be tested
/// without rendering.
enum AmbientClock {
    /// Locale-aware time, e.g. "9:41" or "21:41" depending on the region's
    /// 12- or 24-hour preference.
    static func timeText(_ date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("j:mm")
        return formatter.string(from: date)
    }

    /// A full weekday-and-date line, e.g. "Sunday, 1 November".
    static func dateText(_ date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return formatter.string(from: date)
    }
}

/// The full-screen ambient display: a large clock with the playing track,
/// weather, battery, and next event beneath it, on a dark wash.
struct AmbientView: View {
    @EnvironmentObject private var settings: ReefSettings
    @EnvironmentObject private var media: NowPlayingController
    @EnvironmentObject private var weather: WeatherProvider
    @EnvironmentObject private var battery: BatteryModel
    @EnvironmentObject private var calendar: CalendarMonitor

    private var nextEvent: CalendarEvent? {
        EventSchedule.next(calendar.events, now: Date())
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.04, green: 0.05, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                clock
                cards
            }
            .padding(60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
    }

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 10) {
                Text(AmbientClock.timeText(context.date))
                    .font(.system(size: 120, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(AmbientClock.dateText(context.date))
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var cards: some View {
        HStack(alignment: .top, spacing: 24) {
            if settings.ambientShowsNowPlaying, let track = media.current {
                nowPlayingCard(track)
            }
            if settings.ambientShowsWeather, let snapshot = weather.snapshot {
                weatherCard(snapshot)
            }
            if settings.ambientShowsBattery, battery.snapshot.isPresent {
                batteryCard(battery.snapshot)
            }
            if settings.ambientShowsNextEvent, let event = nextEvent {
                eventCard(event)
            }
        }
    }

    // MARK: - Cards

    private func nowPlayingCard(_ track: NowPlaying) -> some View {
        AmbientCard {
            HStack(spacing: 16) {
                Group {
                    if let artwork = track.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            Rectangle().fill(.white.opacity(0.08))
                            Image(systemName: "music.note")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Label(track.isPlaying ? "Now Playing" : "Paused",
                        systemImage: track.isPlaying ? "waveform" : "pause.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .labelStyle(.titleAndIcon)
                    Text(track.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(maxWidth: 220, alignment: .leading)
            }
        }
    }

    private func weatherCard(_ snapshot: WeatherSnapshot) -> some View {
        AmbientCard {
            HStack(spacing: 16) {
                Image(systemName: snapshot.condition.symbol)
                    .font(.system(size: 40))
                    .symbolRenderingMode(.multicolor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.temperatureText)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(snapshot.condition.label)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                    if let high = snapshot.highText, let low = snapshot.lowText {
                        Text("H:\(high)  L:\(low)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
    }

    private func batteryCard(_ snapshot: BatterySnapshot) -> some View {
        AmbientCard {
            HStack(spacing: 16) {
                Image(systemName: batterySymbol(snapshot))
                    .font(.system(size: 34))
                    .foregroundStyle(snapshot.isCharging ? .green : .white)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(snapshot.percent)%")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(snapshot.isCharging ? "Charging"
                        : snapshot.isPluggedIn ? "Plugged in" : "On battery")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    private func eventCard(_ event: CalendarEvent) -> some View {
        AmbientCard {
            VStack(alignment: .leading, spacing: 6) {
                Label("Up Next", systemImage: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Text(event.title)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(event.countdownText(now: Date()))
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: 200, alignment: .leading)
        }
    }

    private func batterySymbol(_ snapshot: BatterySnapshot) -> String {
        if snapshot.isCharging { return "battery.100percent.bolt" }
        switch snapshot.percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

/// A rounded, translucent tile the ambient cards share.
private struct AmbientCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.06)))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }
}
