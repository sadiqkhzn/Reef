import Foundation

/// What the island shows while resting, when nothing transient is happening.
enum RestingActivity: String, CaseIterable, Identifiable {
    /// Now playing only.
    case nowPlaying
    /// The next calendar event only.
    case calendar
    /// Now playing while a track is on, the next event otherwise.
    case both
    /// Nothing; the bare pill.
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: return "Playing"
        case .calendar: return "Calendar"
        case .both: return "Both"
        case .none: return "None"
        }
    }

    /// Which slot the resting island fills, given what is available. Pure, so the
    /// choice is tested without the overlay. A narrow pill can show one thing at
    /// a time, so "Both" prefers the playing track and falls back to the event.
    func slot(hasMedia: Bool, hasEvent: Bool) -> RestingSlot {
        switch self {
        case .nowPlaying:
            return hasMedia ? .media : .empty
        case .calendar:
            return hasEvent ? .event : .empty
        case .both:
            if hasMedia { return .media }
            return hasEvent ? .event : .empty
        case .none:
            return .empty
        }
    }
}

/// What the resting island is showing.
enum RestingSlot {
    case media
    case event
    case empty
}
