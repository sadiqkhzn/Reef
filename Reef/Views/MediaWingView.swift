import AppKit
import SwiftUI

/// The resting media activity.
///
/// Album art sits on the leading side and a lively equalizer on the trailing
/// side, tinted with a color drawn from the art. Hovering the trailing side
/// turns the equalizer into a play/pause button over a slowly revolving glow;
/// clicking it toggles playback. While paused the bars fall quiet.
struct MediaWingView: View {
    let nowPlaying: NowPlaying
    @ObservedObject var media: NowPlayingController
    var height: CGFloat
    /// Width of the notch to leave clear in the center, so the cover and the
    /// equalizer sit out in the two wings. Zero on Macs without a notch, where
    /// the pill simply holds both ends.
    var notchWidth: CGFloat = 0
    /// False while hopping screens, so the motion stops.
    var animating: Bool = true
    /// Real audio loudness for the equalizer, when the live waveform is on.
    var liveLevels: [Float]? = nil
    /// Reports when the pointer is over the trailing control, so the island
    /// knows not to open while a button is hovered.
    var onControlHover: (Bool) -> Void = { _ in }
    /// Called when the user resumes playback from the control, so the island can
    /// announce the track.
    var onResume: () -> Void = {}

    @State private var controlHovered = false
    @State private var controlPressed = false

    /// Vivid color from the cover, computed once by the controller.
    private var tint: Color { nowPlaying.tint ?? .white }

    private var coverSide: CGFloat { max(16, height - 7) }
    private var coverRadius: CGFloat { coverSide * 0.3 }

    /// Margin from each end, a touch tighter than the old inset so the cover and
    /// equalizer sit nearer the corners without crowding the rounded edge.
    private let endInset: CGFloat = 7

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            cover
                .id(nowPlaying.artworkToken ?? 0)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.easeInOut(duration: 0.3), value: nowPlaying.artworkToken)
                .padding(.leading, endInset)
            // The center holds at least the notch width and takes up any extra,
            // so the cover and equalizer stay pinned to the two corners and the
            // gap grows between them when the island peeks wider.
            Spacer(minLength: max(10, notchWidth))
            control
                .padding(.trailing, endInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cover

    @ViewBuilder
    private var cover: some View {
        if let image = nowPlaying.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: coverSide, height: coverSide)
                .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .frame(width: coverSide, height: coverSide)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: coverSide * 0.42, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7)))
        }
    }

    // MARK: - Trailing control

    private var control: some View {
        ZStack {
            if controlHovered {
                revolvingGlow
                Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .scaleEffect(controlPressed ? 0.78 : 1)
                    .transition(.opacity)
            } else {
                MediaEqualizer(
                    tint: tint,
                    active: animating && nowPlaying.isPlaying,
                    levels: liveLevels)
                    .transition(.opacity)
            }
        }
        // Hug the trailing edge so the equalizer's end margin matches the cover's,
        // while the wider frame keeps an easy hover target.
        .frame(width: 30, height: height, alignment: .trailing)
        .contentShape(Rectangle())
        .onHover { hovering in
            controlHovered = hovering
            onControlHover(hovering)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in controlPressed = true }
                .onEnded { _ in
                    controlPressed = false
                    let wasPaused = !nowPlaying.isPlaying
                    media.playPause()
                    if wasPaused { onResume() }
                })
        .animation(.easeInOut(duration: 0.18), value: controlHovered)
        .animation(.spring(response: 0.26, dampingFraction: 0.55), value: controlPressed)
    }

    private var revolvingGlow: some View {
        TimelineView(.animation) { timeline in
            let angle = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 4) / 4 * 360
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            tint.opacity(0.0), tint.opacity(0.65),
                            tint.opacity(0.0), tint.opacity(0.0),
                        ],
                        center: .center))
                .frame(width: 26, height: 26)
                .blur(radius: 4)
                .rotationEffect(.degrees(angle))
        }
    }

}

/// A row of bars that bounce independently, so it reads as music rather than a
/// single synced wave. Tinted, and quiet (short and still) when inactive.
struct MediaEqualizer: View {
    var tint: Color
    var active: Bool
    var barCount: Int = 4
    /// Recent real audio loudness, newest last. When present (and active), the
    /// bars follow it instead of the canned motion.
    var levels: [Float]? = nil

    var body: some View {
        if active, let levels, !levels.isEmpty {
            liveBars(levels)
        } else if active {
            TimelineView(.animation) { timeline in
                bars(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            bars(time: 0, quiet: true)
        }
    }

    /// Bars driven by the real audio: the most recent loudness values scroll
    /// across the bars, so the equalizer tracks the music.
    private func liveBars(_ levels: [Float]) -> some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom))
                    .frame(width: 3, height: liveHeight(levels, index: index))
            }
        }
        .frame(height: 16)
        .animation(.easeOut(duration: 0.08), value: levels)
    }

    private func liveHeight(_ levels: [Float], index: Int) -> CGFloat {
        // Map each bar to one of the most recent loudness values.
        let offset = barCount - 1 - index
        let value = levels.count > offset ? levels[levels.count - 1 - offset] : 0
        return 3 + CGFloat(max(0, min(1, value))) * 13
    }

    private func bars(time: TimeInterval, quiet: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom))
                    .frame(width: 3, height: quiet ? 3 : height(time: time, index: index))
            }
        }
        .frame(height: 16)
        .animation(.easeOut(duration: 0.12), value: quiet)
    }

    /// Each bar follows its own pair of waves at different rates, so they rise
    /// and fall out of step with each other.
    private func height(time: TimeInterval, index: Int) -> CGFloat {
        let seed = Double(index) * 7.13
        let a = sin(time * (3.1 + Double(index) * 0.9) + seed)
        let b = sin(time * (5.7 + Double(index) * 1.4) + seed * 1.7)
        let value = (a * 0.6 + b * 0.4) * 0.5 + 0.5
        return 3 + CGFloat(value) * 13
    }
}

