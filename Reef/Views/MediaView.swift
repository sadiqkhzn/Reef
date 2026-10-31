import AppKit
import SwiftUI

/// The open media panel: artwork, track details, the source app, a scrubbable
/// progress bar, and the full control row. Artwork comes straight from the
/// player when available; otherwise a tinted tile with a glyph stands in.
struct MediaView: View {
    let nowPlaying: NowPlaying
    @ObservedObject var media: NowPlayingController
    /// How the panel is colored behind the track details.
    var colorStyle: PlayerTint = .bloom

    /// Vivid color drawn from the cover, falling back to white.
    private var tint: Color { nowPlaying.tint ?? .white }

    /// Bring the playing app to the front.
    private func showInApp() {
        guard let id = nowPlaying.bundleIdentifier else { return }
        NSRunningApplication.runningApplications(withBundleIdentifier: id).first?
            .activate(options: [.activateAllWindows])
    }

    var body: some View {
        HStack(spacing: 14) {
            artwork
                .id(nowPlaying.artworkToken ?? 0)
                .transition(.artworkFlip)
                .animation(.easeInOut(duration: 0.4), value: nowPlaying.artworkToken)

            VStack(alignment: .leading, spacing: 4) {
                if let appName = nowPlaying.appName {
                    Button(action: showInApp) {
                        HStack(spacing: 3) {
                            Text(appName.uppercased())
                            if nowPlaying.bundleIdentifier != nil {
                                Image(systemName: "arrow.up.forward")
                            }
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(nowPlaying.bundleIdentifier == nil)
                }

                MarqueeText(
                    text: nowPlaying.title,
                    color: .white,
                    font: .system(size: 14, weight: .semibold))
                    .frame(height: 18)

                Text(nowPlaying.artist)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)

                ScrubBar(track: nowPlaying, tint: tint) { media.seek(to: $0) }
                    .padding(.top, 2)

                controls
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(playerWash)
    }

    /// The color laid behind the panel, following the chosen player style.
    @ViewBuilder
    private var playerWash: some View {
        switch colorStyle {
        case .bloom:
            if let image = nowPlaying.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 36)
                    .opacity(0.5)
                    .overlay(Color.black.opacity(0.28))
                    .allowsHitTesting(false)
            } else {
                solidWash
            }
        case .solid:
            solidWash
        case .gradient:
            LinearGradient(
                colors: [tint.opacity(0.42), tint.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
                .allowsHitTesting(false)
        case .minimal:
            Color.clear
        }
    }

    private var solidWash: some View {
        tint.opacity(0.24).allowsHitTesting(false)
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = nowPlaying.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                .frame(width: 72, height: 72)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8)))
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            toggle("shuffle", on: nowPlaying.shuffleOn) { media.toggleShuffle() }
            Spacer(minLength: 0)
            button("backward.fill", size: 14) { media.previous() }
            Spacer(minLength: 0)
            button(nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: 19) { media.playPause() }
            Spacer(minLength: 0)
            button("forward.fill", size: 14) { media.next() }
            Spacer(minLength: 0)
            toggle(repeatSymbol, on: nowPlaying.repeatMode != .off) { media.cycleRepeat() }
        }
    }

    private var repeatSymbol: String {
        nowPlaying.repeatMode == .one ? "repeat.1" : "repeat"
    }

    private func button(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// A smaller control that lights up in the cover tint when its mode is on.
    private func toggle(_ symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(on ? tint : .white.opacity(0.4))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A thin progress bar that advances on its own and can be dragged to seek.
///
/// The reported position is sampled with a timestamp, so the fill is computed
/// live from the clock rather than waiting for the player to send every tick.
/// Dragging shows the pending position until the finger lifts, then seeks.
private struct ScrubBar: View {
    let track: NowPlaying
    var tint: Color
    var onSeek: (TimeInterval) -> Void

    @State private var dragFraction: Double?

    private var duration: TimeInterval { track.duration ?? 0 }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let live = track.position(at: Date().timeIntervalSince1970) ?? 0
            let fraction = dragFraction ?? (duration > 0 ? live / duration : 0)
            let shown = dragFraction.map { $0 * duration } ?? live

            VStack(spacing: 3) {
                rail(fraction: fraction)
                HStack {
                    Text(Self.clock(shown))
                    Spacer()
                    Text(Self.clock(duration))
                }
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.45))
            }
            // Redraw ties to the timeline tick so the parent is left alone.
            .id(timeline.date.timeIntervalSinceReferenceDate)
        }
    }

    private func rail(fraction: Double) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let clamped = min(max(0, fraction), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.18))
                Capsule()
                    .fill(tint.opacity(0.9))
                    .frame(width: width * clamped)
            }
            .contentShape(Rectangle())
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
        .frame(height: 4)
    }

    /// Seconds as m:ss, or -:-- when the length is unknown.
    private static func clock(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
