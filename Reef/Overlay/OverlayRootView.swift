import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Which page the open island shows.
enum OpenPage {
    case nowPlaying
    case home
    case shelf
}

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
    @EnvironmentObject private var calendar: CalendarMonitor
    @EnvironmentObject private var weather: WeatherProvider
    @EnvironmentObject private var shelf: ShelfModel
    @StateObject private var media = NowPlayingController()
    /// True while a file drag is hovering the island, so it can open the shelf.
    @State private var dropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// True while the mouse button is down on the resting island, which dips
    /// it slightly so a click feels physical.
    @State private var isPressed = false
    /// Bundle id of the frontmost app, for the "hide while the source app is
    /// frontmost" option.
    @State private var frontmostBundleId: String?
    /// Which page the open island shows when a track is playing: the player, or
    /// the home page with the clock, battery, and next event.
    @State private var openPage: OpenPage = .nowPlaying

    private var style: OverlayStyle { state.displayedStyle }
    private var isOpen: Bool { state.phase == .expanded }

    /// The next event to show on the resting island, when the option is on and
    /// nothing is playing. Nil otherwise.
    private var restingEvent: CalendarEvent? {
        guard settings.showsEventAtRest, shownTrack == nil else { return nil }
        return EventSchedule.next(calendar.events, now: Date())
    }

    /// Whether the open island is showing the home page rather than the player.
    /// Home when there is no track, or when the person flipped to it.
    private var showsHome: Bool { shownTrack == nil || openPage == .home }
    /// A track exists, so the open island can flip between player and home.
    private var canSwitchPage: Bool { shownTrack != nil }

    /// The track to actually show, after the source filter and the
    /// frontmost-app rule. Nil means the island shows no media right now.
    private var shownTrack: NowPlaying? {
        MediaGate.shownTrack(
            media.current,
            source: settings.mediaSource,
            hideWhenSourceFrontmost: settings.hidesMediaWhenSourceFrontmost,
            frontmostBundleIdentifier: frontmostBundleId)
    }

    /// The small button on the open player that flips to the home page.
    @ViewBuilder
    private var pageSwitch: some View {
        Button {
            openPage = .home
        } label: {
            Image(systemName: "house.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 22, height: 22)
                .background(Circle().fill(.white.opacity(0.14)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .padding(.trailing, 10)
        .onHover { state.isOverControl = $0 }
    }

    /// Pick a sensible page each time the island opens: the player when a track
    /// is on, the home page otherwise.
    private func resetOpenPage() {
        openPage = shownTrack != nil ? .nowPlaying : .home
    }

    /// Keep the shared now-playing flag in step with whether a track is actually
    /// being shown, so the window's hover region and sizing follow the gate.
    private func updateNowPlayingActive() {
        let active = shownTrack != nil
        state.nowPlayingActive = active
        if !active { state.isOverControl = false }
        state.eventRestingActive = restingEvent != nil
    }

    /// Turn a finished drag on the island into an open/close, a track skip, or a
    /// plain tap-to-open. A tap over a control never opens the island.
    private func handleDrag(_ translation: CGSize) {
        func tapOpen() {
            if state.phase == .collapsed && !state.isOverControl {
                state.phase = .expanded
            }
        }

        guard settings.swipeGesturesEnabled else {
            tapOpen()
            return
        }

        switch SwipeGesture.action(
            translation: translation,
            isOpen: isOpen,
            hasMedia: shownTrack != nil,
            naturalDirection: settings.naturalSwipeDirection) {
        case .tap:
            tapOpen()
        // A sideways swipe flips the page while open, or skips tracks while resting.
        case .nextTrack:
            if isOpen { flipPage() } else { media.next() }
        case .previousTrack:
            if isOpen { flipPage() } else { media.previous() }
        case .open:
            state.phase = .expanded
        case .close:
            state.phase = .collapsed
        case .none:
            break
        }
    }

    /// Flip the open island between the player and the home page.
    private func flipPage() {
        guard canSwitchPage else { return }
        openPage = showsHome ? .nowPlaying : .home
    }

    /// Take dropped files onto the shelf and open it to show them.
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !fileProviders.isEmpty else { return false }

        for provider in fileProviders {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.isFileURL else { return }
                Task { @MainActor in shelf.add([url]) }
            }
        }
        state.phase = .expanded
        openPage = .shelf
        return true
    }

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
                    if openPage == .shelf {
                        ShelfView(
                            shelf: shelf,
                            accent: settings.accent.color,
                            headerHeight: state.collapsedSize.height,
                            notchWidth: notchClearance,
                            onClose: { openPage = shownTrack != nil ? .nowPlaying : .home })
                            .frame(width: state.visibleSize.width, height: state.visibleSize.height)
                            .transition(.islandOpen)
                    } else if let nowPlaying = shownTrack, !showsHome {
                        MediaView(nowPlaying: nowPlaying, media: media, colorStyle: settings.playerTint)
                            .frame(width: state.visibleSize.width, height: state.visibleSize.height)
                            .overlay(alignment: .topTrailing) { pageSwitch }
                            .transition(.islandOpen)
                    } else {
                        IslandHomeView(
                            battery: battery.snapshot,
                            accent: settings.accent.color,
                            headerHeight: state.collapsedSize.height,
                            notchWidth: notchClearance,
                            nextEvent: EventSchedule.next(calendar.events, now: Date()),
                            weather: settings.showsWeather ? weather.snapshot : nil,
                            canOpenPlayer: canSwitchPage,
                            onOpenPlayer: { openPage = .nowPlaying },
                            shelfCount: shelf.items.count,
                            onOpenShelf: { openPage = .shelf })
                            .frame(width: state.visibleSize.width, height: state.visibleSize.height)
                            .transition(.islandOpen)
                    }
                } else if let activity = state.liveActivity {
                    // A live activity briefly takes over the wings, even while a
                    // track is resting, then the media wing returns when it ends.
                    LiveActivityWings(
                        activity: activity,
                        centerWidth: state.collapsedSize.width,
                        rowHeight: state.collapsedSize.height,
                        showsLabel: notchClearance == 0,
                        isPeeking: state.isPeeking)
                        .frame(height: state.restingSize.height, alignment: .top)
                        .transition(.islandWing)
                } else if let nowPlaying = shownTrack {
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
                                notchWidth: notchClearance,
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
                    // Follow the small peek grow on hover (so the corners stretch
                    // out), but stay off the live-activity width: that keeps the
                    // equalizer from sliding across when an activity swaps in.
                    .frame(
                        width: state.mediaWingWidth + (state.isHovering ? NotchState.peekGrow.width : 0),
                        height: state.visibleSize.height,
                        alignment: .top)
                    .transition(.islandWing)
                } else if let event = restingEvent {
                    // Idle, with the next-event option on: show it in the wings.
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                        RestingEventView(
                            event: event,
                            centerWidth: state.collapsedSize.width,
                            rowHeight: state.collapsedSize.height,
                            showsTitle: notchClearance == 0,
                            now: timeline.date)
                    }
                    .frame(height: state.restingSize.height, alignment: .top)
                    .transition(.islandWing)
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
        .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted) { providers in
            handleDrop(providers)
        }
        .onChange(of: dropTargeted) { _, targeted in
            // Opening the shelf the moment a file hovers gives a place to drop.
            if targeted {
                state.phase = .expanded
                openPage = .shelf
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { value in
                    isPressed = false
                    handleDrag(value.translation)
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
            MotionStyle.animation(settings.motion.wings, reduceMotion: reduceMotion),
            value: state.eventRestingActive)
        .animation(
            MotionStyle.animation(settings.motion.peek, reduceMotion: reduceMotion),
            value: state.announcingTitle)
        .onReceive(media.$current) { _ in updateNowPlayingActive() }
        .onReceive(calendar.$events) { _ in updateNowPlayingActive() }
        .onChange(of: settings.showsEventAtRest) { _, _ in updateNowPlayingActive() }
        .onChange(of: isOpen) { _, open in if !open { resetOpenPage() } }
        .onChange(of: settings.mediaSource) { _, _ in updateNowPlayingActive() }
        .onChange(of: settings.hidesMediaWhenSourceFrontmost) { _, _ in updateNowPlayingActive() }
        .onChange(of: frontmostBundleId) { _, _ in updateNowPlayingActive() }
        .onReceive(
            NSWorkspace.shared.notificationCenter
                .publisher(for: NSWorkspace.didActivateApplicationNotification)
        ) { note in
            frontmostBundleId = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                .bundleIdentifier
        }
        .onAppear {
            frontmostBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            updateNowPlayingActive()
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
