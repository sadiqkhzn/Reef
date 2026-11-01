import XCTest
@testable import Reef

/// Covers choosing the next event and the countdown text.
final class CalendarEventTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func event(
        _ id: String, startsIn minutes: Double, lasts duration: Double = 60, allDay: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: id,
            start: now.addingTimeInterval(minutes * 60),
            end: now.addingTimeInterval((minutes + duration) * 60),
            isAllDay: allDay,
            colorHex: nil)
    }

    // MARK: - Countdown

    func testCountdownMinutes() {
        XCTAssertEqual(event("a", startsIn: 5).countdownText(now: now), "in 5 min")
        XCTAssertEqual(event("a", startsIn: 1).countdownText(now: now), "in 1 min")
    }

    func testCountdownRoundsUp() {
        // 90 seconds away reads as 2 min, never 1.
        let e = CalendarEvent(
            id: "x", title: "x",
            start: now.addingTimeInterval(90), end: now.addingTimeInterval(3600),
            isAllDay: false, colorHex: nil)
        XCTAssertEqual(e.countdownText(now: now), "in 2 min")
    }

    func testCountdownHours() {
        XCTAssertEqual(event("a", startsIn: 60).countdownText(now: now), "in 1 hr")
        XCTAssertEqual(event("a", startsIn: 130).countdownText(now: now), "in 2 hr 10 min")
    }

    func testOngoingReadsNow() {
        let e = event("a", startsIn: -5, lasts: 30)
        XCTAssertTrue(e.isOngoing(now: now))
        XCTAssertEqual(e.countdownText(now: now), "Now")
    }

    // MARK: - Lead window

    func testWithinLead() {
        let e = event("a", startsIn: 8)
        XCTAssertTrue(e.isWithinLead(now: now, leadTime: 10 * 60))
        XCTAssertFalse(e.isWithinLead(now: now, leadTime: 5 * 60))
        // Already started events are not in the lead window.
        XCTAssertFalse(event("b", startsIn: -1).isWithinLead(now: now, leadTime: 10 * 60))
    }

    func testShortCountdown() {
        XCTAssertEqual(event("a", startsIn: 10).shortCountdownText(now: now), "10m")
        XCTAssertEqual(event("a", startsIn: 90).shortCountdownText(now: now), "1h")
        XCTAssertEqual(event("a", startsIn: -5, lasts: 30).shortCountdownText(now: now), "now")
    }

    // MARK: - Next event

    func testNextPicksSoonestUnendedTimedEvent() {
        let events = [
            event("later", startsIn: 60),
            event("soon", startsIn: 10),
            event("past", startsIn: -120, lasts: 30),   // already ended
            event("allday", startsIn: 5, allDay: true),  // ignored
        ]
        XCTAssertEqual(EventSchedule.next(events, now: now)?.id, "soon")
    }

    func testNextIncludesOngoing() {
        let events = [event("ongoing", startsIn: -5, lasts: 30), event("later", startsIn: 40)]
        XCTAssertEqual(EventSchedule.next(events, now: now)?.id, "ongoing")
    }

    func testNextIsNilWhenNothingLeft() {
        XCTAssertNil(EventSchedule.next([event("done", startsIn: -120, lasts: 30)], now: now))
        XCTAssertNil(EventSchedule.next([event("allday", startsIn: 10, allDay: true)], now: now))
    }

    // MARK: - Meeting link

    private func event(withURL url: URL? = nil, location: String? = nil, notes: String? = nil)
        -> CalendarEvent {
        CalendarEvent(
            id: "m", title: "m", start: now, end: now.addingTimeInterval(3600),
            isAllDay: false, colorHex: nil, location: location, url: url, notes: notes)
    }

    func testMeetingURLFromEventURL() {
        let e = event(withURL: URL(string: "https://zoom.us/j/123456")!)
        XCTAssertEqual(e.meetingURL?.host, "zoom.us")
    }

    func testMeetingURLFoundInNotes() {
        let e = event(notes: "Agenda below.\nJoin: https://meet.google.com/abc-defg-hij\nThanks")
        XCTAssertEqual(e.meetingURL?.host, "meet.google.com")
    }

    func testMeetingURLPrefersKnownHost() {
        // A plain link and a conferencing link both present: the known host wins.
        let e = event(
            location: "https://example.com/docs",
            notes: "call https://teams.microsoft.com/l/meetup-join/xyz")
        XCTAssertEqual(e.meetingURL?.host, "teams.microsoft.com")
    }

    func testMeetingURLFallsBackToAnyLink() {
        let e = event(notes: "Notes at https://example.com/page")
        XCTAssertEqual(e.meetingURL?.absoluteString, "https://example.com/page")
    }

    func testNoMeetingURLWhenNoneAttached() {
        XCTAssertNil(event(location: "Room 4B", notes: "Bring coffee").meetingURL)
    }
}
