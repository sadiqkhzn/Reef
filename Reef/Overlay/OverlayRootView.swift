import SwiftUI

/// The SwiftUI root hosted inside the overlay panel.
///
/// The panel never changes size. This view draws the island at the size the
/// current state calls for, anchored to the top center, and animates between
/// the states:
///
/// - resting: matches the notch, or a small pill on Macs without one;
/// - peek: grows a touch the moment the pointer arrives;
/// - wings: spreads left and right around the notch for a live activity;
/// - open: the full panel, after a short pause handled by the window
///   controller;
/// - relocating: shrinks and fades while it hops to another screen.
struct OverlayRootView: View {
    @EnvironmentObject private var state: NotchState
    @EnvironmentObject private var settings: ReefSettings
    @EnvironmentObject private var battery: BatteryModel
    @StateObject private var media = NowPlayingController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// True while the mouse button is down on the resting island, which dips
    /// it slightly so a click feels physical.
    @State private var isPressed = false

    private var style: OverlayStyle { state.displayedStyle }
    private var isOpen: Bool { state.phase == .expanded }

    private var shape: NotchShape {
        switch style {
        case .attached:
            return NotchShape(
                topCornerRadius: 6,
                bottomCornerRadius: isOpen ? ReefTheme.Radius.island : 13,
                shoulder: style.shoulder)
        case .floating:
            // Equal radii give a uniformly rounded bubble. Use the resting
            // height for the radius so the curvature stays the same even when the
            // island grows taller for an announcement.
            let radius = isOpen ? ReefTheme.Radius.island : state.restingSize.height / 2
            return NotchShape(topCornerRadius: radius, bottomCornerRadius: radius)
        }
    }

    /// Solid band height that keeps the hardware notch hidden under glass.
    private var notchBand: CGFloat {
        style == .attached && state.hasNotch ? state.collapsedSize.height : 0
    }

    /// Width of the middle of the header and wings that is left clear for the
    /// hardware notch.
    private var notchClearance: CGFloat {
        state.hasNotch && style == .attached ? state.collapsedSize.width : 0
    }

    private var sizeAnimation: Animation {
        MotionStyle.animation(
            isOpen ? settings.motion.open : settings.motion.close,
            reduceMotion: reduceMotion)
    }

    /// The cover's vivid color, or the accent as a fallback.
    private var mediaTint: Color {
        media.current?.tint ?? settings.accent.color
    }

    /// A soft gradient of the media tint, shared by the equalizer and the
    /// announcement band so they read as one look.
    private var tintGradient: LinearGradient {
        LinearGradient(
            colors: [mediaTint.opacity(0.85), mediaTint.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack(alignment: .top) {
            IslandSurface(
                shape: shape,
                material: settings.material,
                notchBand: notchBand,
                isHighlighted: state.isHovering)
                .frame(
                    width: state.visibleSize.width + style.shoulder * 2,
                    height: state.visibleSize.height)
                .shadow(
                    color: .black.opacity(style.hasShadow ? (isOpen ? 0.32 : 0.24) : 0),
                    radius: isOpen ? 8 : 3,
                    y: isOpen ? 3 : 0)

            Group {
                if isOpen {
                    if let nowPlaying = media.current {
                        MediaView(nowPlaying: nowPlaying, media: media)
                            .frame(width: state.visibleSize.width, height: state.visibleSize.height)
                            .transition(.islandContentFast)
                    } else {
                        IslandHomeView(
                            battery: battery.snapshot,
                            accent: settings.accent.color,
                            headerHeight: state.collapsedSize.height,
                            notchWidth: notchClearance)
                            .frame(width: state.visibleSize.width, height: state.visibleSize.height)
                            .transition(.islandContentFast)
                    }
                } else if let nowPlaying = media.current {
                    // One stable wing, so toggling play/pause never rebuilds it.
                    // The announcement just grows a title band below it.
                    ZStack(alignment: .top) {
                        if state.announcingTitle != nil {
                            LinearGradient(
                                colors: [.clear, mediaTint.opacity(0.45)],
                                startPoint: .center,
                                endPoint: .bottom)
                        }
                        VStack(spacing: 0) {
                            MediaWingView(
                                nowPlaying: nowPlaying,
                                media: media,
                                height: state.collapsedSize.height,
                                animating: !state.isRelocating,
                                onControlHover: { state.isOverControl = $0 },
                                onResume: { state.announce(nowPlaying.title) })
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            if state.announcingTitle != nil {
                                MarqueeText(
                                    text: state.announcingTitle ?? "",
                                    color: .white.opacity(0.95),
                                    font: .system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 18)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                    .frame(width: state.visibleSize.width, height: state.visibleSize.height, alignment: .top)
                    .transition(.islandContentFast)
                } else if let activity = state.liveActivity {
                    LiveActivityWings(
                        activity: activity,
                        centerWidth: state.collapsedSize.width,
                        rowHeight: state.collapsedSize.height,
                        showsLabel: notchClearance == 0,
                        isPeeking: state.isPeeking)
                        .frame(height: state.restingSize.height, alignment: .top)
                        .transition(.islandContentFast)
                }
            }
            // Keep the content inside the island so it closes with it rather than
            // lingering outside the shrinking silhouette.
            .frame(width: state.visibleSize.width, height: state.visibleSize.height, alignment: .top)
            .clipShape(shape)
        }
        .scaleEffect(isPressed && !isOpen && !state.isOverControl ? 0.96 : 1, anchor: .top)
        .animation(
            MotionStyle.animation(MotionStyle.Spring(response: 0.3, dampingFraction: 0.7), reduceMotion: reduceMotion),
            value: isPressed)
        .frame(width: state.hitSize.width, height: state.hitSize.height, alignment: .top)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    // Click the bare island to open it at once. A control sets
                    // isOverControl, so clicking a button never opens it.
                    if state.phase == .collapsed && !state.isOverControl {
                        state.phase = .expanded
                    }
                })
        .onHover { hovering in
            state.isHovering = hovering
        }
        .animation(sizeAnimation, value: state.phase)
        .animation(
            MotionStyle.animation(settings.motion.peek, reduceMotion: reduceMotion),
            value: state.isHovering)
        .animation(
            MotionStyle.animation(settings.motion.wings, reduceMotion: reduceMotion),
            value: state.liveActivity)
        .animation(
            MotionStyle.animation(settings.motion.wings, reduceMotion: reduceMotion),
            value: state.isPeeking)
        .animation(
            MotionStyle.animation(settings.motion.wings, reduceMotion: reduceMotion),
            value: media.current)
        .animation(
            MotionStyle.animation(settings.motion.wings, reduceMotion: reduceMotion),
            value: state.nowPlayingActive)
        .animation(
            MotionStyle.animation(settings.motion.peek, reduceMotion: reduceMotion),
            value: state.announcingTitle)
        .onReceive(media.$current) { current in
            state.nowPlayingActive = current != nil
            if current == nil { state.isOverControl = false }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Hopping to another screen: shrink and fade out, then pop back in on the
        // new screen rather than teleporting.
        .scaleEffect(state.isRelocating ? 0.9 : 1, anchor: .top)
        .opacity(state.isRelocating ? 0 : 1)
        .animation(
            state.isRelocating
                ? .easeIn(duration: 0.12)
                : MotionStyle.animation(settings.motion.peek, reduceMotion: reduceMotion),
            value: state.isRelocating)
        // The island is always dark, whatever the system appearance, so system
        // materials and symbols render for a dark surface.
        .environment(\.colorScheme, .dark)
    }
}
