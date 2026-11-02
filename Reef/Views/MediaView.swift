import AppKit
import CoreAudio
import SwiftUI

/// The open media hero: large artwork with an album-color glow and a source-app
/// badge, the track details, a scrubbable progress bar, and a circular transport
/// row with a dominant play control. Artwork comes straight from the player when
/// available; otherwise a tinted tile with a glyph stands in.
struct MediaView: View {
    let nowPlaying: NowPlaying
    @ObservedObject var media: NowPlayingController
    /// Trim video/lyrics noise from the title.
    var cleanTitle: Bool = false
    /// Accent used for the dominant play control.
    var accent: Color = .white
    /// Live audio levels for the equalizer, when the live waveform is on.
    var liveLevels: [Float]? = nil
    /// How the panel is colored behind the track details.
    var colorStyle: PlayerTint = .bloom
    /// Whether to fetch and offer synced lyrics for the current track.
    var lyricsEnabled: Bool = false

    /// Called when an in-island panel (volume) or the lyrics overlay opens or
    /// closes, so the host can pin the island open while the user interacts.
    var onInteractionChange: (Bool) -> Void = { _ in }

    /// The current output device, for the speaker icon. The volume panel manages
    /// its own copy so dragging the slider never re-renders the hero.
    @State private var outputs: [OutputDevice] = []
    @State private var currentOutputID: AudioObjectID?
    /// Whether the volume/device panel is open.
    @State private var showOutput = false
    /// Synced lyrics for the current track, and whether the overlay is showing.
    @StateObject private var lyrics = LyricsModel()
    @State private var showLyrics = false

    /// Vivid color drawn from the cover, falling back to white.
    private var tint: Color { nowPlaying.tint ?? .white }

    /// Identity of the current track, so lyrics reload only when the song changes.
    private var trackKey: String { "\(nowPlaying.title)|\(nowPlaying.artist)" }

    private func showInApp() {
        guard let id = nowPlaying.bundleIdentifier else { return }
        NSRunningApplication.runningApplications(withBundleIdentifier: id).first?
            .activate(options: [.activateAllWindows])
    }

    private func copyTrack() {
        let artist = nowPlaying.artist.trimmingCharacters(in: .whitespaces)
        let title = nowPlaying.displayTitle(cleaned: cleanTitle)
        let text = artist.isEmpty ? title : "\(title) - \(artist)"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    var body: some View {
        HStack(spacing: 14) {
            artwork
                .id(nowPlaying.artworkToken ?? 0)
                .transition(.artworkFlip)
                .animation(.easeInOut(duration: 0.4), value: nowPlaying.artworkToken)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    MarqueeText(
                        text: nowPlaying.displayTitle(cleaned: cleanTitle),
                        color: .white,
                        font: .system(size: 14, weight: .semibold, design: .rounded),
                        alignment: .leading)
                        .frame(height: 18)
                        // Soft trailing fade so the title dissolves into the ↗
                        // arrow instead of clipping hard against it.
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle().fill(.black)
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .leading, endPoint: .trailing)
                                    .frame(width: 16)
                            })
                    if lyricsEnabled && lyrics.hasLyrics {
                        Button { showLyrics.toggle() } label: {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(showLyrics ? tint : .white.opacity(0.55))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Lyrics")
                    }
                    if nowPlaying.bundleIdentifier != nil {
                        Button(action: showInApp) {
                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.55))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Open in app")
                    }
                }

                Text(nowPlaying.artist)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                Spacer(minLength: 2)

                ScrubBar(track: nowPlaying, tint: tint) { media.seek(to: $0) }

                controls
                    .padding(.top, 2)
            }
            .frame(height: 96)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        // Hide the hero entirely under the lyrics overlay so nothing shows
        // through (no double-vision of the art, scrubber, or transport).
        .opacity(showLyrics ? 0 : 1)
        .allowsHitTesting(!showLyrics)
        // Center vertically so the hero clears the top notch band and reads as a
        // balanced card.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(playerWash)
        .overlay {
            if showLyrics {
                LyricsView(
                    model: lyrics, nowPlaying: nowPlaying, media: media,
                    cleanTitle: cleanTitle, accent: tint,
                    onClose: { showLyrics = false })
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if showOutput {
                ZStack(alignment: .bottomLeading) {
                    // A tap outside the panel dismisses it, while staying inside
                    // the island so the panel doesn't vanish on mouse-move.
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture { showOutput = false }
                    MediaOutputPanel(media: media)
                        .padding(.leading, 12)
                        .padding(.bottom, 40)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showLyrics)
        .animation(.easeInOut(duration: 0.15), value: showOutput)
        .onChange(of: showOutput) { _, _ in onInteractionChange(showOutput || showLyrics) }
        .onChange(of: showLyrics) { _, _ in onInteractionChange(showOutput || showLyrics) }
        .onDisappear { onInteractionChange(false) }
        .task(id: trackKey) {
            guard lyricsEnabled else { return }
            showLyrics = false
            lyrics.load(
                title: nowPlaying.displayTitle(cleaned: cleanTitle),
                artist: nowPlaying.artist,
                album: nowPlaying.album,
                duration: nowPlaying.duration)
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc", action: copyTrack)
            if nowPlaying.bundleIdentifier != nil {
                Button("Show in App", systemImage: "arrow.up.forward.app", action: showInApp)
            }
        }
    }

    // MARK: - Artwork + glow + source badge

    @ViewBuilder
    private var artwork: some View {
        cover
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(glow)
    }

    /// The live equalizer tucked into the artwork's bottom-left corner, on a
    /// small dark pill so the bars read on any cover. Opposite the source badge.
    @ViewBuilder
    private var equalizer: some View {
        if let levels = liveLevels, nowPlaying.isPlaying {
            MediaEqualizer(tint: .white, active: true, barCount: 7, levels: levels)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(.black.opacity(0.4)))
                .padding(5)
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let image = nowPlaying.artwork {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8)))
        }
    }

    /// Soft mood lighting pulled from the cover, behind the artwork.
    @ViewBuilder
    private var glow: some View {
        if let image = nowPlaying.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 96, height: 96)
                .blur(radius: 26)
                .scaleEffect(1.3)
                .opacity(nowPlaying.isPlaying ? 0.55 : 0.32)
                .allowsHitTesting(false)
        } else {
            tint.opacity(0.4).blur(radius: 26).allowsHitTesting(false)
        }
    }

    /// The playing app's icon, tucked into the artwork's corner.
    @ViewBuilder
    private var sourceBadge: some View {
        if let icon = Self.appIcon(nowPlaying.bundleIdentifier) {
            Button(action: showInApp) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .padding(5)
        }
    }

    private static func appIcon(_ bundleID: String?) -> NSImage? {
        guard let bundleID,
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    // MARK: - Wash

    @ViewBuilder
    private var playerWash: some View {
        switch colorStyle {
        case .bloom:
            if let image = nowPlaying.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 40)
                    .opacity(0.45)
                    .overlay(Color.black.opacity(0.3))
                    // Bottom-heavy scrim so the scrubber and transport stay legible
                    // over bright album colors.
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.35)],
                            startPoint: .center,
                            endPoint: .bottom))
                    .allowsHitTesting(false)
            } else {
                tint.opacity(0.22).allowsHitTesting(false)
            }
        case .solid:
            tint.opacity(0.22).allowsHitTesting(false)
        case .gradient:
            LinearGradient(
                colors: [tint.opacity(0.4), tint.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
                .allowsHitTesting(false)
        case .minimal:
            Color.clear
        }
    }

    // MARK: - Transport

    private var controls: some View {
        HStack(spacing: 0) {
            outputPicker
            Spacer(minLength: 0)
            transportToggle("shuffle", on: nowPlaying.shuffleOn) { media.toggleShuffle() }
            Spacer(minLength: 0)
            transportButton("backward.fill", size: 13, diameter: 26) { media.previous() }
            Spacer(minLength: 0)
            playButton
            Spacer(minLength: 0)
            transportButton("forward.fill", size: 13, diameter: 26) { media.next() }
            Spacer(minLength: 0)
            transportToggle(repeatSymbol, on: nowPlaying.repeatMode != .off) { media.cycleRepeat() }
        }
    }

    // MARK: - Output picker

    /// A speaker button that opens the in-island volume + output panel. Its icon
    /// shows where audio is going.
    private var outputPicker: some View {
        Button { showOutput.toggle() } label: {
            Image(systemName: currentOutputSymbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Volume & output")
        .onAppear(perform: refreshOutputs)
        .onReceive(media.$current) { _ in refreshOutputs() }
    }

    /// The symbol of the current route, defaulting to a speaker.
    private var currentOutputSymbol: String {
        outputs.first { $0.id == currentOutputID }?.symbol ?? "speaker.wave.2.fill"
    }

    /// Only refreshes the icon's device info — never volume, so nothing here
    /// changes while the slider is being dragged in the panel.
    private func refreshOutputs() {
        outputs = AudioOutputDevices.available()
        currentOutputID = AudioOutputDevices.currentDefaultID()
    }

    private var repeatSymbol: String {
        nowPlaying.repeatMode == .one ? "repeat.1" : "repeat"
    }

    private var playButton: some View {
        Button(action: { media.playPause() }) {
            ZStack {
                Circle().fill(accent.opacity(0.95)).frame(width: 32, height: 32)
                Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent.contrastingInk)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Circle())
        }
        .buttonStyle(HoverScaleStyle())
    }

    private func transportButton(
        _ symbol: String, size: CGFloat, diameter: CGFloat, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(HoverScaleStyle())
    }

    private func transportToggle(
        _ symbol: String, on: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(on ? tint : .white.opacity(0.45))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .buttonStyle(HoverScaleStyle())
    }
}

/// A button style that lifts slightly on hover and dips on press — the circular
/// transport feel without a filled background.
private struct HoverScaleStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(.white.opacity(hovering ? 0.12 : 0))
                    .scaleEffect(0.92))
            .scaleEffect(configuration.isPressed ? 0.9 : (hovering ? 1.08 : 1))
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovering)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .onHover { hovering = $0 }
    }
}

/// A progress bar that advances on its own and can be dragged to seek. It swells
/// from 4pt to 8pt while hovered or dragged, and shows elapsed / −remaining.
private struct ScrubBar: View {
    let track: NowPlaying
    var tint: Color
    var onSeek: (TimeInterval) -> Void

    @State private var dragFraction: Double?
    @State private var hovering = false

    private var duration: TimeInterval { track.duration ?? 0 }
    private var active: Bool { hovering || dragFraction != nil }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let live = track.position(at: Date().timeIntervalSince1970) ?? 0
            let fraction = dragFraction ?? (duration > 0 ? live / duration : 0)
            let shown = dragFraction.map { $0 * duration } ?? live

            VStack(spacing: 4) {
                rail(fraction: fraction)
                HStack {
                    Text(Self.clock(shown))
                    Spacer()
                    Text("-" + Self.clock(max(0, duration - shown)))
                }
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
            }
            .id(timeline.date.timeIntervalSinceReferenceDate)
        }
    }

    private func rail(fraction: Double) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let clamped = min(max(0, fraction), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule().fill(tint.opacity(0.95)).frame(width: width * clamped)
                if active {
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .offset(x: width * clamped - 5)
                }
            }
            .contentShape(Rectangle().inset(by: -6))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        dragFraction = min(max(0, value.location.x / width), 1)
                    }
                    .onEnded { value in
                        guard duration > 0 else { return }
                        let f = min(max(0, value.location.x / width), 1)
                        dragFraction = nil
                        onSeek(f * duration)
                    })
        }
        .frame(height: active ? 8 : 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: active)
        .onHover { hovering = $0 }
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// The in-island volume + output panel. It owns its own volume/mute/device state
/// so dragging the slider re-renders only this small panel — never the media
/// hero — which keeps the scrubber behind it from flickering.
private struct MediaOutputPanel: View {
    @ObservedObject var media: NowPlayingController

    @State private var outputs: [OutputDevice] = []
    @State private var currentOutputID: AudioObjectID?
    @State private var volume: Double = 0.5
    @State private var muted = false
    @State private var volumeSupported = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if volumeSupported {
                HStack(spacing: 8) {
                    Button { toggleMute() } label: {
                        Image(systemName: muted ? "speaker.slash.fill" : "speaker.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(muted ? .secondary : .primary)
                            .frame(width: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Slider(value: $volume, in: 0...1)
                        .controlSize(.small)
                        .onChange(of: volume) { _, newValue in
                            guard let id = currentOutputID else { return }
                            AudioOutputDevices.setVolume(Float(newValue), on: id)
                            if muted, newValue > 0 { muted = false }
                        }
                }
                Divider()
            }
            ForEach(outputs) { device in
                Button {
                    AudioOutputDevices.setDefault(device.id)
                    refresh()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: device.id == currentOutputID ? "checkmark" : device.symbol)
                            .font(.system(size: 11))
                            .frame(width: 16)
                            .foregroundStyle(device.id == currentOutputID ? Color.accentColor : .secondary)
                        Text(device.name)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 210)
        .background(
            RoundedRectangle(cornerRadius: ReefTheme.Radius.card, style: .continuous)
                .fill(.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: ReefTheme.Radius.card, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.45), radius: 12, y: 4))
        .onAppear(perform: refresh)
        .onReceive(media.$current) { _ in refresh() }
    }

    private func refresh() {
        outputs = AudioOutputDevices.available()
        currentOutputID = AudioOutputDevices.currentDefaultID()
        if let id = currentOutputID, let level = AudioOutputDevices.volume(of: id) {
            volumeSupported = true
            volume = Double(level)
            muted = AudioOutputDevices.isMuted(id)
        } else {
            volumeSupported = false
        }
    }

    private func toggleMute() {
        guard let id = currentOutputID else { return }
        let next = !muted
        if AudioOutputDevices.setMuted(next, on: id) {
            muted = next
        } else if next {
            // No mute property: drop volume to zero as a soft mute.
            AudioOutputDevices.setVolume(0, on: id)
            volume = 0
            muted = true
        }
    }
}
