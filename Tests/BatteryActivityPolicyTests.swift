import XCTest
@testable import Reef

/// Checks which battery changes earn a live activity.
final class BatteryActivityPolicyTests: XCTestCase {

    private func snapshot(_ percent: Int, charging: Bool = false, plugged: Bool = false)
        -> BatterySnapshot {
        BatterySnapshot(
            isPresent: true, percent: percent, isCharging: charging, isPluggedIn: plugged)
    }

    func testPluggingInShowsCharging() {
        let activity = BatteryActivityPolicy.activity(
            from: snapshot(54), to: snapshot(54, charging: true, plugged: true))

        XCTAssertEqual(activity, .charging(percent: 54))
    }

    func testCustomLowThreshold() {
        // With a 30% threshold, crossing 30 warns.
        XCTAssertEqual(
            BatteryActivityPolicy.activity(from: snapshot(32), to: snapshot(29), lowThreshold: 30),
            .lowBattery(percent: 29, isCritical: false))
        // The same drop does not warn at the default 20% threshold.
        XCTAssertNil(
            BatteryActivityPolicy.activity(from: snapshot(32), to: snapshot(29), lowThreshold: 20))
    }

    func testLowThresholdNeverBelowCritical() {
        // A threshold under the critical level still only warns at critical.
        XCTAssertNil(
            BatteryActivityPolicy.activity(from: snapshot(12), to: snapshot(11), lowThreshold: 5))
    }

    func testPluggingInWhenFullShowsFullyCharged() {
        let activity = BatteryActivityPolicy.activity(
            from: snapshot(100), to: snapshot(100, plugged: true))

        XCTAssertEqual(activity, .fullyCharged)
    }

    func testPluggingInBelowFullWithoutChargingStillShowsCharging() {
        // Optimized charging can hold the battery below full on wall power.
        let activity = BatteryActivityPolicy.activity(
            from: snapshot(80), to: snapshot(80, plugged: true))

        XCTAssertEqual(activity, .charging(percent: 80))
    }

    func testReachingFullOnWallPowerShowsFullyCharged() {
        let activity = BatteryActivityPolicy.activity(
            from: snapshot(99, charging: true, plugged: true),
            to: snapshot(100, plugged: true))

        XCTAssertEqual(activity, .fullyCharged)
    }

    func testChargingTickDoesNothing() {
        let activity = BatteryActivityPolicy.activity(
            from: snapshot(60, charging: true, plugged: true),
            to: snapshot(61, charging: true, plugged: true))

        XCTAssertNil(activity)
    }

    func testUnpluggingDoesNothing() {
        let activity = BatteryActivityPolicy.activity(
            from: snapshot(70, charging: true, plugged: true), to: snapshot(70))

        XCTAssertNil(activity)
    }

    func testCrossingLowThresholdWarns() {
        let activity = BatteryActivityPolicy.activity(from: snapshot(21), to: snapshot(20))

        XCTAssertEqual(activity, .lowBattery(percent: 20, isCritical: false))
    }

    func testCrossingCriticalThresholdEscalates() {
        let activity = BatteryActivityPolicy.activity(from: snapshot(11), to: snapshot(10))

        XCTAssertEqual(activity, .lowBattery(percent: 10, isCritical: true))
    }

    func testJumpPastBothThresholdsReportsCritical() {
        // A long sleep can skip straight past both thresholds.
        let activity = BatteryActivityPolicy.activity(from: snapshot(25), to: snapshot(8))

        XCTAssertEqual(activity, .lowBattery(percent: 8, isCritical: true))
    }

    func testStayingLowDoesNotRepeat() {
        let activity = BatteryActivityPolicy.activity(from: snapshot(18), to: snapshot(17))

        XCTAssertNil(activity)
    }

    func testNoBatteryNeverShows() {
        let activity = BatteryActivityPolicy.activity(from: .absent, to: .absent)

        XCTAssertNil(activity)
    }

    func testCriticalOutranksCharging() {
        XCTAssertGreaterThan(
            LiveActivity.lowBattery(percent: 5, isCritical: true).priority,
            LiveActivity.charging(percent: 5).priority)
        XCTAssertGreaterThan(
            LiveActivity.charging(percent: 5).priority,
            LiveActivity.fullyCharged.priority)
    }

    func testStatusWording() {
        XCTAssertEqual(snapshot(40, charging: true, plugged: true).status, .charging)
        XCTAssertEqual(snapshot(100, plugged: true).status, .fullyCharged)
        XCTAssertEqual(snapshot(80, plugged: true).status, .notCharging)
        XCTAssertEqual(snapshot(80).status, .onBattery)
    }
}
