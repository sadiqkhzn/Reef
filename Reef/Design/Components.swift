import SwiftUI

/// A circular progress ring.
///
/// Used for battery charge today, and meant for timers, downloads, stats
/// gauges, and the circular HUD as those arrive. The ring sweeps in from empty
/// when it appears and springs to each new value, so a gauge reads as live
/// rather than printed. With Reduce Motion on, it jumps straight to the value.
struct RingGauge: View {
    /// Progress from 0 to 1. Values outside that range are clamped.
    var progress: Double
    var tint: Color
    var lineWidth: CGFloat = 5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    private var clamped: Double { min(1, max(0, progress)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(
                    tint.gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.45), radius: 4)
        }
        .padding(lineWidth / 2)
        .onAppear { show(clamped) }
        .onChange(of: clamped) { _, value in show(value) }
    }

    private func show(_ value: Double) {
        guard !reduceMotion else {
            shown = value
            return
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.9)) {
            shown = value
        }
    }
}

/// A card inside the open island.
///
/// Cards use a plain translucent fill and a hairline rather than another layer
/// of glass, and their corner radius is concentric with the island's.
struct IslandCard: ViewModifier {
    var padding: CGFloat = ReefTheme.Spacing.m

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: ReefTheme.Radius.card, style: .continuous)
                    .fill(ReefTheme.Ink.fill))
            .overlay(
                RoundedRectangle(cornerRadius: ReefTheme.Radius.card, style: .continuous)
                    .strokeBorder(ReefTheme.Ink.stroke, lineWidth: 0.5))
    }
}

extension View {
    func islandCard(padding: CGFloat = ReefTheme.Spacing.m) -> some View {
        modifier(IslandCard(padding: padding))
    }
}

/// Blur and fade together, the way content resolves on the iPhone Dynamic
/// Island instead of simply fading.
private struct BlurFade: ViewModifier {
    var radius: CGFloat
    var opacity: Double
    var scale: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: radius)
            .opacity(opacity)
            .scaleEffect(scale, anchor: .top)
    }
}

extension AnyTransition {
    /// Content blurs and shrinks slightly toward the top as it leaves, and
    /// resolves from that state as it arrives.
    static var islandContent: AnyTransition {
        .modifier(
            active: BlurFade(radius: 8, opacity: 0, scale: 0.96),
            identity: BlurFade(radius: 0, opacity: 1, scale: 1))
    }
}
