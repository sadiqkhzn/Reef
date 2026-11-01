import AppKit
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

    /// Vivid color drawn from the cover, falling back to white.
    private var tint: Color { nowPlaying.tint ?? .white }

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

            VStack(alignment: .leading, spacing: 5) {
                MarqueeText(
                    text: nowPlaying.displayTitle(cleaned: cleanTitle),
                    color: .white,
                    font: .system(size: 15, weight: .semibold, design: .rounded),
                    alignment: .leading)
                    .frame(height: 19)

                Text(nowPlaying.artist)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                Spacer(minLength: 6)

                ScrubBar(track: nowPlaying, tint: tint) { media.seek(to: $0) }

                controls
                    .padding(.top, 6)
            }
            .frame(height: 96)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        // Center vertically so the hero clears the top notch band and reads as a
        // balanced card.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(playerWash)
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
            .overlay(alignment: .bottomLeading) { equalizer }
            .overlay(alignment: .bottomTrailing) { sourceBadge }
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
            transportToggle("shuffle", on: nowPlaying.shuffleOn) { media.toggleShuffle() }
            Spacer(minLength: 0)
            transportButton("backward.fill", size: 15, diameter: 30) { media.previous() }
            Spacer(minLength: 0)
            playButton
            Spacer(minLength: 0)
            transportButton("forward.fill", size: 15, diameter: 30) { media.next() }
            Spacer(minLength: 0)
            transportToggle(repeatSymbol, on: nowPlaying.repeatMode != .off) { media.cycleRepeat() }
        }
    }

    private var repeatSymbol: String {
        nowPlaying.repeatMode == .one ? "repeat.1" : "repeat"
    }

    private var playButton: some View {
        Button(action: { media.playPause() }) {
            ZStack {
                Circle().fill(accent.opacity(0.9)).frame(width: 38, height: 38)
                Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(on ? tint : .white.opacity(0.45))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
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
