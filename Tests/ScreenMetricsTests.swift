import XCTest
@testable import Reef

/// Exercises the overlay placement math. None of this needs a real screen, so
/// the values are fed in directly and the frames checked by hand.
final class ScreenMetricsTests: XCTestCase {

    // MARK: - Notch detection

    func testNotchDetectedWhenSafeAreaPresent() {
        let notch = ScreenMetrics.notch(
            safeAreaTop: 38,
            screenWidth: 1512,
            leftAreaWidth: 640,
            rightAreaWidth: 640)

        XCTAssertTrue(notch.exists)
        XCTAssertEqual(notch.size.height, 38, accuracy: 0.001)
        // 1512 - 640 - 640 = 232
        XCTAssertEqual(notch.size.width, 232, accuracy: 0.001)
    }

    func testNoNotchWhenSafeAreaIsZero() {
        let notch = ScreenMetrics.notch(
            safeAreaTop: 0,
            screenWidth: 2560,
            leftAreaWidth: nil,
            rightAreaWidth: nil)

        XCTAssertFalse(notch.exists)
        XCTAssertEqual(notch.size, .zero)
    }

    func testNotchFallsBackWhenAreasMissing() {
        let notch = ScreenMetrics.notch(
            safeAreaTop: 32,
            screenWidth: 1512,
            leftAreaWidth: nil,
            rightAreaWidth: nil)

        XCTAssertTrue(notch.exists)
        XCTAssertEqual(notch.size.width, ScreenMetrics.fallbackNotchWidth, accuracy: 0.001)
        XCTAssertEqual(notch.size.height, 32, accuracy: 0.001)
    }

    func testNotchFallsBackWhenAreasAreZero() {
        let notch = ScreenMetrics.notch(
            safeAreaTop: 32,
            screenWidth: 1512,
            leftAreaWidth: 0,
            rightAreaWidth: 0)

        XCTAssertEqual(notch.size.width, ScreenMetrics.fallbackNotchWidth, accuracy: 0.001)
    }

    // MARK: - Collapsed size

    func testCollapsedSizeMatchesNotch() {
        let notch = ScreenMetrics.Notch(exists: true, size: CGSize(width: 232, height: 38))
        XCTAssertEqual(ScreenMetrics.collapsedSize(for: notch), CGSize(width: 232, height: 38))
    }

    func testCollapsedSizeUsesDefaultPillWithoutNotch() {
        let notch = ScreenMetrics.Notch(exists: false, size: .zero)
        XCTAssertEqual(ScreenMetrics.collapsedSize(for: notch), ScreenMetrics.defaultPillSize)
    }

    // MARK: - Frame placement

    func testOverlayFrameCentersAtTopOfPrimaryScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let size = CGSize(width: 232, height: 38)

        let frame = ScreenMetrics.overlayFrame(screenFrame: screen, size: size)

        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, screen.maxY, accuracy: 0.001)
        XCTAssertEqual(frame.width, 232, accuracy: 0.001)
        XCTAssertEqual(frame.height, 38, accuracy: 0.001)
    }

    func testOverlayFrameRespectsTopInset() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = ScreenMetrics.defaultPillSize

        let frame = ScreenMetrics.overlayFrame(screenFrame: screen, size: size, topInset: 3)

        XCTAssertEqual(frame.maxY, screen.maxY - 3, accuracy: 0.001)
        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.001)
    }

    func testOverlayFrameHonorsScreenOrigin() {
        // A second display placed to the right of the primary one.
        let screen = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
        let size = CGSize(width: 190, height: 32)

        let frame = ScreenMetrics.overlayFrame(screenFrame: screen, size: size)

        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(frame.minX, screen.minX)
        XCTAssertEqual(frame.maxY, screen.maxY, accuracy: 0.001)
    }
}
