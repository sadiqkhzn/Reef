import XCTest
@testable import Reef

/// Checks how the overlay state reports its target size across phases.
@MainActor
final class NotchStateTests: XCTestCase {

    func testStartsCollapsed() {
        let state = NotchState()
        XCTAssertEqual(state.phase, .collapsed)
        XCTAssertFalse(state.isHovering)
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
        XCTAssertEqual(state.targetSize.height, NotchState.expandedHeight, accuracy: 0.001)
    }

    func testExpandedKeepsWiderCollapsedWidth() {
        let state = NotchState()
        // A collapsed width already wider than the expanded minimum.
        state.collapsedSize = CGSize(width: 460, height: 38)
        state.phase = .expanded

        XCTAssertEqual(state.targetSize.width, 460, accuracy: 0.001)
    }
}
