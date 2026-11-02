import SwiftUI

/// A lyrics overlay for the Now Playing hero: synced lyrics scroll and highlight
/// with playback; a plain transcript scrolls on its own. Tapping dismisses.
struct LyricsView: View {
    @ObservedObject var model: LyricsModel
    let nowPlaying: NowPlaying
    var accent: Color
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.black.opacity(0.35)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .background(.black.opacity(0.55))
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var content: some View {
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
        TimelineView(.periodic(from: .now, by: 0.3)) { _ in
            let position = nowPlaying.position(at: Date().timeIntervalSince1970) ?? 0
            let active = model.activeIndex(at: position)
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(model.lines.enumerated()), id: \.element.id) { index, line in
                            Text(line.text.isEmpty ? "♪" : line.text)
                                .font(.system(
                                    size: index == active ? 15 : 13,
                                    weight: index == active ? .bold : .medium,
                                    design: .rounded))
                                .foregroundStyle(
                                    index == active ? .white
                                        : .white.opacity(index == (active ?? -1) + 1 ? 0.55 : 0.32))
                                .id(index)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .animation(.easeOut(duration: 0.2), value: active)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 40)
                }
                .onChange(of: active) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 24)
                Rectangle().fill(.black)
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 24)
            })
    }

    private func plainScroll(_ text: String) -> some View {
        ScrollView(showsIndicators: false) {
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
        }
        .mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 16)
                Rectangle().fill(.black)
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 16)
            })
    }
}
