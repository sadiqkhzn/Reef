import AppKit
import SwiftUI

/// A lyrics companion for the Now Playing hero: the album atmosphere stays, a
/// compact mini-player sits on the left, and the synced lyrics scroll on the
/// right with Apple Music-style depth — the active line large and bright, its
/// neighbors dimmed and softly blurred. Clicking a line seeks there.
struct LyricsView: View {
    @ObservedObject var model: LyricsModel
    let nowPlaying: NowPlaying
    @ObservedObject var media: NowPlayingController
    var cleanTitle: Bool = false
    var accent: Color
    var onClose: () -> Void

    @State private var hovered: Int?
    @State private var coverHover = false

    private var tint: Color { nowPlaying.tint ?? accent }

    var body: some View {
        ZStack {
            atmosphere
            HStack(spacing: 14) {
                miniPlayer
                    .frame(width: 124)
                stage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            // Keep the lyric column clear of the bottom tab bar.
            .padding(.bottom, 16)
        }
    }

    // MARK: - Background

    /// The same sampled album glow as Now Playing, a touch stronger, over a dark
    /// scrim so lyrics float on glowing colored smoke rather than flat black.
    private var atmosphere: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.55))
            if let image = nowPlaying.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 45)
                    .opacity(0.42)
            }
            RadialGradient(
                colors: [tint.opacity(0.35), .clear],
                center: .topLeading, startRadius: 0, endRadius: 260)
                .blur(radius: 24)
            Rectangle().fill(.black.opacity(0.28))
        }
        .allowsHitTesting(false)
    }

    // MARK: - Left mini-player

    private var miniPlayer: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            // The art doubles as a way back: click it to morph to the full player.
            Button(action: onClose) {
                cover
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.black.opacity(coverHover ? 0.35 : 0)))
                    .overlay {
                        if coverHover {
                            Image(systemName: "arrow.down.left.and.arrow.up.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                    .scaleEffect(coverHover ? 1.04 : 1)
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Back to player")
            .onHover { coverHover = $0 }
            .animation(.snappy(duration: 0.15), value: coverHover)

            VStack(spacing: 2) {
                Text(nowPlaying.displayTitle(cleaned: cleanTitle))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(nowPlaying.artist)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .multilineTextAlignment(.center)

            microTransport
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let image = nowPlaying.artwork {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.3))
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8)))
        }
    }

    private var microTransport: some View {
        HStack(spacing: 12) {
            Button { media.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Button { media.playPause() } label: {
                Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .contentTransition(.symbolEffect(.replace))
            }
            Button { media.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            // Lit because lyrics are on; tapping toggles back to the player.
            Button(action: onClose) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.white))
                    .contentShape(Circle())
            }
            .help("Hide lyrics")
        }
        .buttonStyle(.plain)
    }

    // MARK: - Right lyric stage

    @ViewBuilder
    private var stage: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .idle, .unavailable:
            placeholder("No lyrics found")
        case .loaded:
            if model.isSynced {
                synced
            } else if let plain = model.plain {
                plainScroll(plain)
            } else {
                placeholder("No lyrics found")
            }
        }
    }

    private func placeholder(_ text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white.opacity(0.5))
            Text(text)
                .font(ReefTheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var synced: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let position = nowPlaying.position(at: Date().timeIntervalSince1970) ?? 0
            let active = model.activeIndex(at: position)
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(model.lines.enumerated()), id: \.element.id) { index, line in
                            lyricLine(index: index, line: line, active: active, position: position)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 56)
                }
                .onChange(of: active) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(.interpolatingSpring(stiffness: 170, damping: 22)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .mask(edgeFade)
    }

    private func lyricLine(
        index: Int, line: LyricsModel.Line, active: Int?, position: TimeInterval
    ) -> some View {
        let distance = active.map { abs(index - $0) } ?? 3
        let isActive = active == index
        let isHovered = hovered == index
        let style = depth(for: distance, hovered: isHovered)
        let gap = nextGap(after: index)
        let instrumental = line.text.isEmpty

        return Button {
            media.seek(to: line.time)
        } label: {
            Group {
                if instrumental && isActive && gap > 5 {
                    beatDots(progress: beatProgress(index: index, position: position))
                } else {
                    Text(instrumental ? "♪" : line.text)
                        .font(.system(size: style.size, weight: style.weight, design: .rounded))
                        .foregroundStyle(.white.opacity(style.opacity))
                        .shadow(color: .white.opacity(isActive ? 0.25 : 0), radius: isActive ? 8 : 0)
                        .blur(radius: style.blur)
                }
            }
            .scaleEffect(style.scale, anchor: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(isHovered && !isActive ? 0.05 : 0)))
            .contentShape(Rectangle())
            .id(index)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? index : (hovered == index ? nil : hovered) }
        .animation(.easeOut(duration: 0.2), value: active)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    /// Optical depth per distance from the active line (hover clears the blur).
    private func depth(for distance: Int, hovered: Bool)
        -> (size: CGFloat, weight: Font.Weight, opacity: Double, blur: CGFloat, scale: CGFloat) {
        if hovered { return (14, .semibold, 0.75, 0, 0.97) }
        switch distance {
        case 0: return (17, .bold, 1.0, 0, 1.0)
        case 1: return (14, .semibold, 0.38, 0.6, 0.95)
        case 2: return (13, .medium, 0.18, 1.4, 0.90)
        default: return (13, .medium, 0.12, 1.4, 0.90)
        }
    }

    private func beatDots(progress: Double) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
                    .scaleEffect(progress * 3 >= Double(i + 1) ? 1 : 0.5)
                    .opacity(progress * 3 >= Double(i + 1) ? 1 : 0.4)
                    .animation(.easeOut(duration: 0.2), value: progress)
            }
        }
    }

    /// Seconds until the next line after `index` (large when it's the last line).
    private func nextGap(after index: Int) -> TimeInterval {
        guard index + 1 < model.lines.count else { return 0 }
        return model.lines[index + 1].time - model.lines[index].time
    }

    private func beatProgress(index: Int, position: TimeInterval) -> Double {
        let start = model.lines[index].time
        let gap = nextGap(after: index)
        guard gap > 0 else { return 1 }
        return min(1, max(0, (position - start) / gap))
    }

    private func plainScroll(_ text: String) -> some View {
        ScrollView(showsIndicators: false) {
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 24)
        }
        .mask(edgeFade)
    }

    /// A clean top/bottom fade so no line is clipped against the island edge.
    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.18),
                .init(color: .black, location: 0.80),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top, endPoint: .bottom)
    }
}
