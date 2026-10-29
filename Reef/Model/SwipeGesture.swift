import CoreGraphics

/// What a drag on the island resolves to. Keeping this pure makes the direction
/// and threshold rules testable without a running overlay.
enum SwipeGesture {
    enum Action: Equatable {
        case tap
        case nextTrack
        case previousTrack
        case open
        case close
        case none
    }

    /// Distance a drag must travel before it counts as a swipe rather than a tap.
    static let threshold: CGFloat = 24
    /// Movement under this in both axes is treated as a plain tap.
    static let tapSlop: CGFloat = 6

    /// Resolve a finished drag.
    ///
    /// - A clear horizontal swipe skips tracks (only when a track is playing).
    ///   With natural direction on, swiping left moves to the next track, the
    ///   way paging content slides; off flips it.
    /// - A clear vertical swipe opens (down) or closes (up) the island.
    /// - Barely any movement is a tap.
    static func action(
        translation: CGSize,
        isOpen: Bool,
        hasMedia: Bool,
        naturalDirection: Bool
    ) -> Action {
        let dx = translation.width
        let dy = translation.height

        if abs(dx) < tapSlop && abs(dy) < tapSlop {
            return .tap
        }

        if abs(dx) > abs(dy) {
            guard abs(dx) >= threshold, hasMedia else { return .none }
            let swipeLeft = dx < 0
            let goesNext = naturalDirection ? swipeLeft : !swipeLeft
            return goesNext ? .nextTrack : .previousTrack
        }

        guard abs(dy) >= threshold else { return .none }
        if dy > 0 {
            return isOpen ? .none : .open
        }
        return isOpen ? .close : .none
    }
}
