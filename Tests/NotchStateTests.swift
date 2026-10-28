import XCTest
@testable import Reef

/// Checks how the overlay state reports its sizes across phases and live
/// activities.
@MainActor
final class NotchStateTests: XCTestCase {

    func testStartsCollapsed() {
        let state = NotchState()
        XCTAssertEqual(state.phase, .collapsed)
        XCTAssertFalse(state.isHovering)
        XCTAssertNil(state.liveActivity)
    }

    func testCollapsedTargetMatchesCollapsedSize() {
        let state = NotchState()
        state.collapsedSize = CGSize(width: 232, height: 38)

        XCTAssertEqual(state.targetSize, CGSize(width: 232, height: 38))
    }

    func testExpandedWidensToAtLeastMinimum() {
        let state = NotchState()
        state.collapsedSize = CGSize(width: 190, height: 32)
        state.phase = .expanded

        XCTAssertEqual(state.targetSize.width, NotchState.expandedMinWidth, accuracy: 0.001)
        XCTAssertEqual(
            state.targetSize.height, 32 + NotchState.expandedBodyHeight, accuracy: 0.001)
    }

    func testExpandedKeepsWiderCollapsedWidth() {
        let state = NotchState()
        // A collapsed width already wider than the expanded minimum.
        state.collapsedSize = CGSize(width: 460, height: 38)
        state.phase = .expanded

        XCTAssertEqual(state.targetSize.width, 460, accuracy: 0.001)
    }

    func testExpandedHeaderMatchesRestingHeight() {
        // The open header row sits beside the notch, so a taller notch makes
        // a taller open island.
        let short = NotchState.expandedSize(collapsed: CGSize(width: 200, height: 24))
        let tall = NotchState.expandedSize(collapsed: CGSize(width: 200, height: 38))

        XCTAssertEqual(tall.height - short.height, 14, accuracy: 0.001)
    }

    func testLiveActivitySpreadsWings() {
        let state = NotchState()
        state.collapsedSize = CGSize(width: 200, height: 32)
        state.liveActivity = .charging(percent: 50)

        XCTAssertEqual(
            state.restingSize.width, 200 + NotchState.wingWidth * 2, accuracy: 0.001)
        XCTAssertEqual(state.restingSize.height, 32, accuracy: 0.001)
        XCTAssertEqual(state.targetSize, state.restingSize)
    }

    func testHitAreaFollowsWings() {
        let state = NotchState()
        state.collapsedSize = CGSize(width: 200, height: 32)
        let plain = state.hitSize

        state.liveActivity = .fullyCharged

        XCTAssertEqual(
            state.hitSize.width - plain.width, NotchState.wingWidth * 2, accuracy: 0.001)
    }

    func testPeekGrowsFromWingedSize() {
        let state = NotchState()
        state.collapsedSize = CGSize(width: 200, height: 32)
        state.liveActivity = .charging(percent: 20)
        state.isHovering = true

        XCTAssertEqual(
            state.visibleSize.width,
            state.restingSize.width + NotchState.peekGrow.width,
            accuracy: 0.001)
    }

    func testOpenIgnoresWings() {
        let state = NotchState()
        state.collapsedSize = CGSize(width: 200, height: 32)
        state.liveActivity = .charging(percent: 20)
        state.phase = .expanded

        XCTAssertEqual(state.visibleSize, state.expandedSize)
    }
}
