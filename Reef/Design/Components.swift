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
            // A recessed dark well — darker than the glass shell — so the card
            // reads as carved into the surface rather than a raised gray box.
            .background(
                RoundedRectangle(cornerRadius: ReefTheme.Radius.card, style: .continuous)
                    .fill(Color.black.opacity(0.22)))
            // Top-lit hairline: a touch of light on the top edge, fading down.
            .overlay(
                RoundedRectangle(cornerRadius: ReefTheme.Radius.card, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.10), .white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom),
                        lineWidth: 0.5))
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

/// A purely vertical blur-fade: content eases down from just above as it
/// arrives and lifts back up as it leaves, so wide content resolves straight
/// from the top with no sideways spread (a scale from the top would splay the
/// two panes outward).
private struct TopBlurFade: ViewModifier {
    var radius: CGFloat
    var opacity: Double
    var yOffset: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: radius)
            .opacity(opacity)
            .offset(y: yOffset)
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

    /// Like `islandContent`, but it leaves quickly so open content is gone before
    /// the island finishes shrinking on close, rather than lingering past it.
    static var islandContentFast: AnyTransition {
        .asymmetric(
            insertion: .islandContent,
            removal: AnyTransition.islandContent.animation(.easeOut(duration: 0.12)))
    }

    /// For the resting wings (media and live activities). A plain blur-fade with
    /// no animation of its own, so it inherits the island's own grow/shrink
    /// spring: the contents resolve and leave in exact step with the silhouette,
    /// in both directions, never arriving or lingering out of time with it.
    static var islandWing: AnyTransition { .islandContent }

    /// A top-origin blur-fade for the open body: it resolves straight down from
    /// the top rather than scaling, so wide two-pane content never splays left
    /// and right as it settles.
    static var islandTop: AnyTransition {
        .modifier(
            active: TopBlurFade(radius: 8, opacity: 0, yOffset: -12),
            identity: TopBlurFade(radius: 0, opacity: 1, yOffset: 0))
    }

    /// For the open island's content. A quick, smooth blur-fade both ways, so
    /// opening feels as smooth as closing. The short timing keeps the tinted body
    /// filling in fast rather than leaving a black island for long.
    static var islandOpen: AnyTransition {
        .asymmetric(
            insertion: AnyTransition.islandTop.animation(.easeOut(duration: 0.22)),
            removal: AnyTransition.islandTop.animation(.easeOut(duration: 0.12)))
    }

    /// For cover art when the track changes: the old art flips away and the new
    /// one flips in, fading as it turns so the swap reads as a card turning over.
    static var artworkFlip: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: ArtworkFlip(angle: -90, opacity: 0),
                identity: ArtworkFlip(angle: 0, opacity: 1)),
            removal: .modifier(
                active: ArtworkFlip(angle: 90, opacity: 0),
                identity: ArtworkFlip(angle: 0, opacity: 1)))
    }
}

/// Rotates content around its vertical axis with a little perspective, fading as
/// it turns, for the artwork flip.
private struct ArtworkFlip: ViewModifier {
    var angle: Double
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .opacity(opacity)
    }
}
