import XCTest
@testable import Reef

/// Covers how a finished drag on the island is read as a tap, a track skip, or
/// an open/close.
final class SwipeGestureTests: XCTestCase {

    private func action(
        _ dx: CGFloat, _ dy: CGFloat,
        isOpen: Bool = false, hasMedia: Bool = true, natural: Bool = true
    ) -> SwipeGesture.Action {
        SwipeGesture.action(
            translation: CGSize(width: dx, height: dy),
            isOpen: isOpen, hasMedia: hasMedia, naturalDirection: natural)
    }

    func testTinyMovementIsTap() {
        XCTAssertEqual(action(2, -3), .tap)
        XCTAssertEqual(action(0, 0), .tap)
    }

    func testNaturalHorizontalSwipes() {
        XCTAssertEqual(action(-40, 2), .nextTrack, "left moves to next with natural on")
        XCTAssertEqual(action(40, -2), .previousTrack)
    }

    func testInvertedHorizontalSwipes() {
        XCTAssertEqual(action(-40, 0, natural: false), .previousTrack)
        XCTAssertEqual(action(40, 0, natural: false), .nextTrack)
    }

    func testHorizontalSwipeNeedsMedia() {
        XCTAssertEqual(action(-40, 0, hasMedia: false), .none)
    }

    func testVerticalOpensAndCloses() {
        XCTAssertEqual(action(0, 40, isOpen: false), .open, "down opens")
        XCTAssertEqual(action(0, -40, isOpen: true), .close, "up closes")
    }

    func testVerticalNoOpWhenAlreadyInThatState() {
        XCTAssertEqual(action(0, 40, isOpen: true), .none, "already open, down does nothing")
        XCTAssertEqual(action(0, -40, isOpen: false), .none, "already closed, up does nothing")
    }

    func testShortSwipeBelowThresholdIsIgnored() {
        // Past the tap slop but short of the swipe threshold.
        XCTAssertEqual(action(12, 0), .none)
        XCTAssertEqual(action(0, 12), .none)
    }

    func testDominantAxisWins() {
        // Mostly horizontal with a little vertical still reads as a skip.
        XCTAssertEqual(action(-40, 10), .nextTrack)
        // Mostly vertical reads as open/close.
        XCTAssertEqual(action(8, 40, isOpen: false), .open)
    }
}
