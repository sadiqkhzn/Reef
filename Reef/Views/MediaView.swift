import SwiftUI

/// The open media panel: artwork, track details, the source app, and transport
/// controls. Artwork comes straight from the player when available; otherwise a
/// tinted tile with a glyph stands in.
struct MediaView: View {
    let nowPlaying: NowPlaying
    @ObservedObject var media: NowPlayingController

    var body: some View {
        HStack(spacing: 14) {
            artwork

            VStack(alignment: .leading, spacing: 3) {
                if let appName = nowPlaying.appName {
                    Text(appName.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Text(nowPlaying.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(nowPlaying.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)

                controls
                    .padding(.top, 6)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = nowPlaying.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8)))
        }
    }

    private var controls: some View {
        HStack(spacing: 20) {
            button("backward.fill", size: 14) { media.previous() }
            button(nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: 18) { media.playPause() }
            button("forward.fill", size: 14) { media.next() }
        }
    }

    private func button(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
