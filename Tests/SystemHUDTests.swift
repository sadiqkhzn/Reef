import XCTest
@testable import Reef

/// Covers the pure parts of the system HUD: the key stepping, the key-code
/// mapping, and how the volume and brightness activities read. The CoreAudio,
/// brightness, and event-tap pieces need hardware and permission, so only the
/// interpretation is tested here.
final class SystemHUDTests: XCTestCase {

    // MARK: - Stepping

    func testStepUpFromZeroGivesOneSixteenth() {
        XCTAssertEqual(HUDStep.stepped(0, up: true), 1 / 16, accuracy: 0.0001)
    }

    func testStepDownFromFullGivesFifteenSixteenths() {
        XCTAssertEqual(HUDStep.stepped(1, up: false), 15 / 16, accuracy: 0.0001)
    }

    func testStepDownFromZeroClampsAtZero() {
        XCTAssertEqual(HUDStep.stepped(0, up: false), 0, accuracy: 0.0001)
    }

    func testStepUpFromFullClampsAtOne() {
        XCTAssertEqual(HUDStep.stepped(1, up: true), 1, accuracy: 0.0001)
    }

    func testSteppingSnapsAnOffGridLevelToTheNearestStep() {
        // 0.5 is exactly eight sixteenths; a nudge up lands on nine.
        XCTAssertEqual(HUDStep.stepped(0.5, up: true), 9 / 16, accuracy: 0.0001)
        // 0.53 snaps to eight sixteenths, then up to nine.
        XCTAssertEqual(HUDStep.stepped(0.53, up: true), 9 / 16, accuracy: 0.0001)
    }

    // MARK: - Key mapping

    func testKnownKeyCodesMapToKeys() {
        XCTAssertEqual(MediaKey(systemDefinedKeyCode: 0), .volumeUp)
        XCTAssertEqual(MediaKey(systemDefinedKeyCode: 1), .volumeDown)
        XCTAssertEqual(MediaKey(systemDefinedKeyCode: 2), .brightnessUp)
        XCTAssertEqual(MediaKey(systemDefinedKeyCode: 3), .brightnessDown)
        XCTAssertEqual(MediaKey(systemDefinedKeyCode: 7), .mute)
    }

    func testOtherKeyCodesAreIgnored() {
        // Play/pause and friends are not ours to handle.
        XCTAssertNil(MediaKey(systemDefinedKeyCode: 16))
        XCTAssertNil(MediaKey(systemDefinedKeyCode: 100))
    }

    // MARK: - Symbols

    func testVolumeSymbolReflectsLevelAndMute() {
        XCTAssertEqual(LiveActivity.volumeSymbol(level: 0.5, muted: true), "speaker.slash.fill")
        XCTAssertEqual(LiveActivity.volumeSymbol(level: 0, muted: false), "speaker.slash.fill")
        XCTAssertEqual(LiveActivity.volumeSymbol(level: 0.2, muted: false), "speaker.wave.1.fill")
        XCTAssertEqual(LiveActivity.volumeSymbol(level: 0.5, muted: false), "speaker.wave.2.fill")
        XCTAssertEqual(LiveActivity.volumeSymbol(level: 0.9, muted: false), "speaker.wave.3.fill")
    }

    func testBrightnessSymbolReflectsLevel() {
        XCTAssertEqual(LiveActivity.brightnessSymbol(level: 0.2), "sun.min.fill")
        XCTAssertEqual(LiveActivity.brightnessSymbol(level: 0.8), "sun.max.fill")
    }

    // MARK: - Activity reading

    func testVolumeDetailAndPriority() {
        let activity = LiveActivity.volume(level: 0.6, muted: false)
        XCTAssertEqual(activity.detail, "Volume · 60%")
        XCTAssertEqual(activity.label, "Volume")
        // HUDs outrank the battery and calendar activities.
        XCTAssertGreaterThan(activity.priority, LiveActivity.lowBattery(percent: 5, isCritical: true).priority)
    }

    func testMutedVolumeReadsAsMuted() {
        let activity = LiveActivity.volume(level: 0, muted: true)
        XCTAssertEqual(activity.detail, "Volume · Muted")
        XCTAssertEqual(activity.accessibilityLabel, "Volume muted")
    }

    func testBrightnessDetail() {
        XCTAssertEqual(LiveActivity.brightness(level: 0.75).detail, "Brightness · 75%")
    }
}
