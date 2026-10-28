import XCTest
@testable import Reef

/// Exercises the power source parsing with hand-built dictionaries, so none of
/// this needs a real battery.
final class BatterySnapshotTests: XCTestCase {

    func testChargingOnWallPower() {
        let snapshot = BatterySnapshot.parse([
            "Current Capacity": 80,
            "Max Capacity": 100,
            "Is Charging": true,
            "Power Source State": "AC Power",
        ])

        XCTAssertTrue(snapshot.isPresent)
        XCTAssertEqual(snapshot.percent, 80)
        XCTAssertTrue(snapshot.isCharging)
        XCTAssertTrue(snapshot.isPluggedIn)
    }

    func testDischargingOnBattery() {
        let snapshot = BatterySnapshot.parse([
            "Current Capacity": 42,
            "Max Capacity": 100,
            "Is Charging": false,
            "Power Source State": "Battery Power",
        ])

        XCTAssertEqual(snapshot.percent, 42)
        XCTAssertFalse(snapshot.isCharging)
        XCTAssertFalse(snapshot.isPluggedIn)
    }

    func testPercentIsScaledAgainstMaxCapacity() {
        // Some machines report capacity against a max other than 100.
        let snapshot = BatterySnapshot.parse([
            "Current Capacity": 2500,
            "Max Capacity": 5000,
            "Is Charging": false,
            "Power Source State": "Battery Power",
        ])

        XCTAssertEqual(snapshot.percent, 50)
    }

    func testPercentRoundsToNearestWhole() {
        let snapshot = BatterySnapshot.parse([
            "Current Capacity": 1,
            "Max Capacity": 3,
            "Is Charging": false,
        ])

        // 1/3 is 33.3, which rounds to 33.
        XCTAssertEqual(snapshot.percent, 33)
    }

    func testPercentIsClampedToHundred() {
        let snapshot = BatterySnapshot.parse([
            "Current Capacity": 110,
            "Max Capacity": 100,
            "Is Charging": true,
            "Power Source State": "AC Power",
        ])

        XCTAssertEqual(snapshot.percent, 100)
    }

    func testMissingCapacityMeansAbsent() {
        let snapshot = BatterySnapshot.parse([
            "Is Charging": false,
            "Power Source State": "AC Power",
        ])

        XCTAssertEqual(snapshot, .absent)
        XCTAssertFalse(snapshot.isPresent)
    }

    func testZeroMaxCapacityMeansAbsent() {
        let snapshot = BatterySnapshot.parse([
            "Current Capacity": 10,
            "Max Capacity": 0,
        ])

        XCTAssertEqual(snapshot, .absent)
    }
}
