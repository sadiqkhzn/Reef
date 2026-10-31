import XCTest
@testable import Reef

/// Covers which slot the resting island fills for each idle-activity choice.
final class RestingActivityTests: XCTestCase {

    func testPlayingShowsMediaOnlyWhenPlaying() {
        XCTAssertEqual(RestingActivity.nowPlaying.slot(hasMedia: true, hasEvent: true), .media)
        XCTAssertEqual(RestingActivity.nowPlaying.slot(hasMedia: false, hasEvent: true), .empty)
    }

    func testCalendarShowsEventOnlyEvenOverMedia() {
        XCTAssertEqual(RestingActivity.calendar.slot(hasMedia: true, hasEvent: true), .event)
        XCTAssertEqual(RestingActivity.calendar.slot(hasMedia: true, hasEvent: false), .empty)
    }

    func testBothPrefersMediaThenEvent() {
        XCTAssertEqual(RestingActivity.both.slot(hasMedia: true, hasEvent: true), .media)
        XCTAssertEqual(RestingActivity.both.slot(hasMedia: false, hasEvent: true), .event)
        XCTAssertEqual(RestingActivity.both.slot(hasMedia: false, hasEvent: false), .empty)
    }

    func testNoneAlwaysEmpty() {
        XCTAssertEqual(RestingActivity.none.slot(hasMedia: true, hasEvent: true), .empty)
    }
}
