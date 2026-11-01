import Foundation

/// One event from the person's calendars, kept free of EventKit so the
/// selection and countdown rules can be tested on their own.
struct CalendarEvent: Equatable, Identifiable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    /// The calendar's color as a hex string, resolved to a real color in the
    /// view. Optional, since not every calendar reports one.
    var colorHex: String?
    /// Identifier of the calendar the event belongs to, for filtering.
    var calendarID: String? = nil
    /// Where the event is, when the calendar gives a location.
    var location: String? = nil
    /// The event's attached URL, when it has one.
    var url: URL? = nil
    /// The event's notes, scanned for a meeting link.
    var notes: String? = nil

    /// A video-call link to join, found in the event's URL, location, or notes.
    /// Returns the first web link, preferring a known conferencing host.
    var meetingURL: URL? {
        let haystacks = [url?.absoluteString, location, notes].compactMap { $0 }
        let links = haystacks.flatMap(Self.webLinks)
        let known = links.first { link in
            let host = link.host?.lowercased() ?? ""
            return Self.meetingHosts.contains { host.contains($0) }
        }
        return known ?? links.first
    }

    /// Conferencing hosts worth preferring when several links are present.
    private static let meetingHosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
        "webex.com", "whereby.com", "meet.jit.si", "around.co", "slack.com",
    ]

    /// Extract http(s) links from a string.
    private static func webLinks(_ text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap { match in
            guard let url = match.url, let scheme = url.scheme?.lowercased(),
                scheme == "http" || scheme == "https" else { return nil }
            return url
        }
    }

    /// True while the event is happening now.
    func isOngoing(now: Date) -> Bool {
        now >= start && now < end
    }

    /// A short, glanceable countdown: "Now" while it runs, otherwise "in 5 min"
    /// or "in 1 hr 10 min". Rounds the minutes up so it never reads a minute
    /// early.
    func countdownText(now: Date) -> String {
        if isOngoing(now: now) { return "Now" }
        let seconds = start.timeIntervalSince(now)
        guard seconds > 0 else { return "Now" }

        let minutes = Int((seconds / 60).rounded(.up))
        if minutes < 60 { return "in \(minutes) min" }

        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "in \(hours) hr" : "in \(hours) hr \(remainder) min"
    }

    /// Whether the event starts within `leadTime` from now, the window in which
    /// the island raises a heads-up for it.
    func isWithinLead(now: Date, leadTime: TimeInterval) -> Bool {
        let seconds = start.timeIntervalSince(now)
        return seconds > 0 && seconds <= leadTime
    }

    /// A very compact countdown for the resting wing: "now", "10m", or "1h".
    func shortCountdownText(now: Date) -> String {
        if isOngoing(now: now) { return "now" }
        let seconds = start.timeIntervalSince(now)
        guard seconds > 0 else { return "now" }
        let minutes = Int((seconds / 60).rounded(.up))
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h"
    }
}

extension String {
    /// The string, or nil when it is empty, for folding blank fields away.
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// A calendar the person can choose to show or hide.
struct CalendarInfo: Identifiable, Equatable {
    var id: String
    var title: String
    var colorHex: String?
}

/// Picks which event matters right now. Pure, so the rules are tested without a
/// calendar store.
enum EventSchedule {
    /// The soonest timed event that has not yet ended. All-day events are left
    /// out, since they do not have a meaningful countdown.
    static func next(_ events: [CalendarEvent], now: Date) -> CalendarEvent? {
        events
            .filter { !$0.isAllDay && $0.end > now }
            .min { $0.start < $1.start }
    }
}
