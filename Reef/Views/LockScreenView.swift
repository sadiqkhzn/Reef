import AppKit
import SwiftUI

/// Reef's lock-screen overlay content.
///
/// The design leaves the wallpaper and the system's own clock open, and adds two
/// things: one quiet glance line of information below the clock, and one rich
/// Now Playing card in the lower third. Everything is display-only (the overlay
/// ignores mouse events for password safety), so transport is shown as a live
/// equalizer rather than buttons that could not work.
struct LockScreenView: View {
    @EnvironmentObject private var settings: ReefSettings
    @EnvironmentObject private var media: NowPlayingController
    @EnvironmentObject private var weather: WeatherProvider
    @EnvironmentObject private var battery: BatteryModel
    @EnvironmentObject private var calendar: CalendarMonitor
    @EnvironmentObject private var lockState: LockScreenState

    private var isLocked: Bool { lockState.phase == .locked }

    private var nextEvent: CalendarEvent? {
        EventSchedule.next(calendar.events, now: Date())
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack {
                scrims
                VStack(spacing: 0) {
                    // Sit just below the system clock, which shows through from
                    // the lock screen behind this transparent overlay.
                    Spacer().frame(height: h * 0.30)
                    // On unlock, the glance line and card clear immediately so the
                    // desktop reads through cleanly behind the unlock animation.
                    if isLocked {
                        GlanceLine(
                            weather: settings.ambientShowsWeather ? weather.snapshot : nil,
                            battery: settings.ambientShowsBattery ? battery.snapshot : nil,
                            event: settings.ambientShowsNextEvent ? nextEvent : nil)
                            .allowsHitTesting(false)
                    }
                    Spacer()
                    if isLocked, settings.ambientShowsNowPlaying, let track = media.current {
                        NowPlayingHeroCard(track: track, style: settings.lockCardStyle)
                            .frame(width: 460)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    // Keep well clear of the avatar and password field below.
                    Spacer().frame(height: h * 0.30)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .top) {
                if settings.lockShowsIsland {
                    LockIslandPill(phase: lockState.phase)
                        .allowsHitTesting(false)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .ignoresSafeArea()
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: media.current?.title)
        // Clear fast on unlock so the desktop appears promptly.
        .animation(.easeOut(duration: 0.14), value: isLocked)
    }

    /// Faint top and bottom gradients so the content reads over any wallpaper.
    private var scrims: some View {
        VStack {
            LinearGradient(colors: [.black.opacity(0.30), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 260)
            Spacer()
            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                .frame(height: 320)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}


// MARK: - Glance line

/// One quiet line of information: weather · moon · battery · next event. Each
/// item leads with a symbol; numbers use monospaced digits so they do not jiggle.
private struct GlanceLine: View {
    let weather: WeatherSnapshot?
    let battery: BatterySnapshot?
    let event: CalendarEvent?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(spacing: 14) {
                if let weather {
                    item(symbol: weather.condition.symbol, multicolor: true) {
                        Text("\(weather.temperatureText) \(weather.condition.label)")
                    }
                    separator
                }
                // Moon phase is always shown; it needs no network.
                item(symbol: MoonPhase.symbol(at: context.date)) {
                    Text(MoonPhase.name(at: context.date))
                }
                if let battery, battery.isPresent {
                    separator
                    item(symbol: batterySymbol(battery),
                        tint: battery.isCharging ? .green : .white.opacity(0.9)) {
                        Text("\(battery.percent)%")
                    }
                }
                if let event {
                    separator
                    item(symbol: "calendar") {
                        Text("\(shortTitle(event.title)) \(timeText(event.start))")
                    }
                }
            }
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .monospacedDigit()
            .lineLimit(1)
            .shadow(color: .black.opacity(0.45), radius: 8, y: 1)
            .padding(.top, 14)
        }
    }

    private func item<Content: View>(
        symbol: String, multicolor: Bool = false, tint: Color = .white.opacity(0.9),
        @ViewBuilder _ text: () -> Content
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .symbolRenderingMode(multicolor ? .multicolor : .monochrome)
                .foregroundStyle(tint)
            text()
        }
    }

    private var separator: some View {
        Text("·").foregroundStyle(.white.opacity(0.4))
    }

    private func shortTitle(_ title: String) -> String {
        title.count > 22 ? String(title.prefix(21)) + "…" : title
    }

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("j:mm")
        return f.string(from: date)
    }

    private func batterySymbol(_ s: BatterySnapshot) -> String {
        if s.isCharging { return "battery.100percent.bolt" }
        switch s.percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

// MARK: - Island pill

/// The real notch island, drawn at its resting size/shape/material on the lock
/// screen, with a padlock that opens on unlock. It reuses the shared NotchState
/// and settings, so it matches the live island exactly — attached or floating,
/// same material, size, and notch handling. Display-only.
private struct LockIslandPill: View {
    @EnvironmentObject private var notch: NotchState
    @EnvironmentObject private var settings: ReefSettings
    let phase: LockScreenState.Phase

    private var style: OverlayStyle { notch.displayedStyle }
    private var unlocking: Bool { phase == .unlocking }

    /// Resting shape, matching OverlayRootView's collapsed island.
    private var shape: NotchShape {
        switch style {
        case .attached:
            return NotchShape(topCornerRadius: 6, bottomCornerRadius: 13, shoulder: style.shoulder)
        case .floating:
            let radius = notch.restingSize.height / 2
            return NotchShape(topCornerRadius: radius, bottomCornerRadius: radius)
        }
    }

    private var notchBand: CGFloat {
        style == .attached && notch.hasNotch ? notch.collapsedSize.height : 0
    }

    /// Clear middle for the hardware notch (attached only).
    private var notchClearance: CGFloat {
        notch.hasNotch && style == .attached ? notch.collapsedSize.width : 0
    }

    /// Place the lock in the right wing when a notch splits the middle, else center.
    private var iconOffsetX: CGFloat {
        guard notchClearance > 0 else { return 0 }
        let wing = (notch.restingSize.width - notchClearance) / 2
        return notchClearance / 2 + wing / 2
    }

    var body: some View {
        IslandSurface(
            shape: shape,
            material: settings.material,
            notchBand: notchBand,
            contrastOutline: settings.contrastOutline)
            .frame(
                width: notch.restingSize.width + style.shoulder * 2,
                height: notch.restingSize.height)
            .overlay {
                Image(systemName: unlocking ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace.downUp))
                    .scaleEffect(unlocking ? 1.25 : 1)
                    .offset(x: iconOffsetX)
                    .animation(.spring(response: 0.35, dampingFraction: 0.55), value: unlocking)
            }
            .shadow(
                color: .black.opacity(style.hasShadow ? 0.24 : 0),
                radius: 3)
            .padding(.top, style.topGap)
            .environment(\.colorScheme, .dark)
    }
}

// MARK: - Now Playing hero card

/// A single rich Now Playing card with a glow drawn from the album art.
private struct NowPlayingHeroCard: View {
    let track: NowPlaying
    var style: LockCardStyle = .glass

    @EnvironmentObject private var media: NowPlayingController

    /// Color theme pulled from the album art, falling back to a cool blue.
    private var tint: Color {
        track.tint ?? Color(red: 0.36, green: 0.5, blue: 0.9)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                artwork
                VStack(alignment: .leading, spacing: 3) {
                    header
                    MarqueeText(
                        text: track.title,
                        color: .white,
                        font: .system(size: 16, weight: .semibold),
                        alignment: .leading)
                        .frame(height: 20)
                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            transport
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(style == .clear ? 0.22 : 0.12), lineWidth: 0.6))
        .opacity(track.isPlaying ? 1 : 0.72)
        // A plain dark drop shadow so the card lifts off the wallpaper without
        // spilling color outside it.
        .shadow(color: .black.opacity(0.4), radius: 22, y: 10)
        .id(track.artworkToken ?? 0)
        .transition(.opacity)
    }

    private var artwork: some View {
        Group {
            if let art = track.artwork {
                Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Rectangle().fill(.white.opacity(0.08))
                    Image(systemName: "music.note")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 6) {
            if let icon = Self.appIcon(track.bundleIdentifier) {
                Image(nsImage: icon).resizable().frame(width: 14, height: 14)
            }
            Text(track.isPlaying ? "Now Playing" : "Paused")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            Spacer(minLength: 0)
            PlayingIndicator(color: .white.opacity(0.85), active: track.isPlaying)
                .allowsHitTesting(false)
        }
    }

    /// Shuffle · previous · play/pause · next · repeat. Interactive — the panel
    /// accepts mouse events on the card only.
    private var transport: some View {
        HStack(spacing: 24) {
            iconButton("shuffle", size: 13, active: track.shuffleOn) { media.toggleShuffle() }
            iconButton("backward.fill", size: 16) { media.previous() }
            iconButton(track.isPlaying ? "pause.fill" : "play.fill", size: 22) { media.playPause() }
            iconButton("forward.fill", size: 16) { media.next() }
            iconButton(track.repeatMode == .one ? "repeat.1" : "repeat",
                size: 13, active: track.repeatMode != .off) { media.cycleRepeat() }
        }
        .padding(.top, 2)
    }

    private func iconButton(
        _ symbol: String, size: CGFloat, active: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(active ? .white : .white.opacity(0.78))
                .frame(width: 36, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var cardBackground: some View {
        switch style {
        case .colored:
            // The album-art color fills the card; a diagonal gradient and a top
            // sheen give it depth. All contained within the card.
            ZStack {
                LinearGradient(
                    colors: [tint.opacity(0.95), tint.opacity(0.68)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                LinearGradient(
                    colors: [.white.opacity(0.14), .clear],
                    startPoint: .top, endPoint: .center)
            }
        case .glass:
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                tint.opacity(0.18)
                LinearGradient(
                    colors: [.white.opacity(0.10), .clear],
                    startPoint: .top, endPoint: .center)
            }
        case .clear:
            // Mostly wallpaper, just a whisper of tint for cohesion.
            ZStack {
                Rectangle().fill(.black.opacity(0.08))
                tint.opacity(0.10)
            }
        }
    }

    private static func appIcon(_ bundleID: String?) -> NSImage? {
        guard let bundleID,
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
