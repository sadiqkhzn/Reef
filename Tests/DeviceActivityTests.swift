import XCTest
@testable import Reef

/// Checks the device connection activity: guessing the kind from a name, and
/// how the activity ranks and reads.
final class DeviceActivityTests: XCTestCase {

    func testRecognizesAirPodsModels() {
        XCTAssertEqual(DeviceKind(name: "Sadiq's AirPods Pro"), .airpodsPro)
        XCTAssertEqual(DeviceKind(name: "AirPods Max"), .airpodsMax)
        XCTAssertEqual(DeviceKind(name: "AirPods"), .airpods)
    }

    func testRecognizesOtherDevices() {
        XCTAssertEqual(DeviceKind(name: "Beats Studio Buds"), .beats)
        XCTAssertEqual(DeviceKind(name: "WH-1000XM5"), .headphones)
        XCTAssertEqual(DeviceKind(name: "Magic Keyboard"), .keyboard)
        XCTAssertEqual(DeviceKind(name: "Magic Trackpad"), .trackpad)
        XCTAssertEqual(DeviceKind(name: "Magic Mouse"), .mouse)
        XCTAssertEqual(DeviceKind(name: "DualSense Wireless Controller"), .gameController)
    }

    func testUnknownNameFallsBack() {
        XCTAssertEqual(DeviceKind(name: "Living Room Speaker"), .other)
        XCTAssertFalse(DeviceKind.other.symbol.isEmpty)
    }

    func testDeviceRanksBetweenChargingAndLowBattery() {
        let device = LiveActivity.deviceConnected(name: "AirPods Pro", kind: .airpodsPro)

        XCTAssertGreaterThan(device.priority, LiveActivity.charging(percent: 50).priority)
        XCTAssertLessThan(
            device.priority, LiveActivity.lowBattery(percent: 20, isCritical: false).priority)
    }

    func testPeekDetailNamesTheDevice() {
        let device = LiveActivity.deviceConnected(name: "AirPods Pro", kind: .airpodsPro)

        XCTAssertEqual(device.detail, "AirPods Pro · Connected")
        XCTAssertEqual(device.accessibilityLabel, "AirPods Pro connected")
    }

    func testPeekNeverOutlastsTheActivity() {
        let all: [LiveActivity] = [
            .charging(percent: 10), .fullyCharged,
            .lowBattery(percent: 10, isCritical: true),
            .deviceConnected(name: "AirPods", kind: .airpods),
        ]
        for activity in all {
            XCTAssertLessThanOrEqual(LiveActivity.peekDuration, activity.duration)
            XCTAssertFalse(activity.detail.isEmpty)
        }
    }

    func testDeviceActivityDefaultsOnAndPersists() {
        let name = "ReefTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let first = ReefSettings(defaults: defaults)
        XCTAssertTrue(first.showsDeviceActivity)
        first.showsDeviceActivity = false

        XCTAssertFalse(ReefSettings(defaults: defaults).showsDeviceActivity)
    }
}
