import XCTest
@testable import Reef

/// Covers the pure battery math: mapping reported cells into one glanceable
/// figure and a readable summary, and dropping devices that report nothing.
final class DeviceBatteryTests: XCTestCase {

    func testEarbudsUseTheLowerSide() {
        let battery = DeviceBattery.make(
            name: "AirPods Pro",
            values: [.left: 80, .right: 65, .case: 90])

        XCTAssertEqual(battery?.overall, 65, "the side that dies first is what matters")
        XCTAssertEqual(battery?.kind, .airpodsPro)
        XCTAssertEqual(battery?.summary, "L 80%  R 65%  Case 90%")
    }

    func testSingleCellDevice() {
        let battery = DeviceBattery.make(name: "Magic Keyboard", values: [.single: 47])

        XCTAssertEqual(battery?.overall, 47)
        XCTAssertEqual(battery?.summary, "47%")
        XCTAssertEqual(battery?.kind, .keyboard)
    }

    func testZeroIsTreatedAsNotReported() {
        // Absent cells read back as zero on some devices.
        let battery = DeviceBattery.make(
            name: "AirPods",
            values: [.left: 0, .right: 55, .case: 0])

        XCTAssertNil(battery?.left)
        XCTAssertNil(battery?.caseLevel)
        XCTAssertEqual(battery?.right, 55)
        XCTAssertEqual(battery?.overall, 55)
        XCTAssertEqual(battery?.summary, "R 55%")
    }

    func testNothingReportedMeansNoBattery() {
        XCTAssertNil(DeviceBattery.make(name: "Some Speaker", values: [:]))
        XCTAssertNil(DeviceBattery.make(name: "Some Speaker", values: [.single: 0]))
    }

    func testLevelsClampToHundred() {
        let battery = DeviceBattery.make(name: "Mouse", values: [.single: 150])
        XCTAssertEqual(battery?.single, 100)
    }
}
