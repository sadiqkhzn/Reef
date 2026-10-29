import CoreAudio
import XCTest
@testable import Reef

/// Covers the pure audio-output classification and how the activity reads. The
/// CoreAudio listening itself needs hardware, so only the interpretation is
/// tested here.
final class AudioOutputTests: XCTestCase {

    func testBuiltInSplitsSpeakersFromHeadphoneJack() {
        XCTAssertEqual(
            AudioOutputKind.classify(
                transportType: kAudioDeviceTransportTypeBuiltIn,
                dataSourceName: "MacBook Pro Speakers"),
            .builtInSpeakers)

        XCTAssertEqual(
            AudioOutputKind.classify(
                transportType: kAudioDeviceTransportTypeBuiltIn,
                dataSourceName: "External Headphones"),
            .headphones)
    }

    func testTransportTypesMapToKinds() {
        XCTAssertEqual(
            AudioOutputKind.classify(transportType: kAudioDeviceTransportTypeBluetooth, dataSourceName: nil),
            .bluetooth)
        XCTAssertEqual(
            AudioOutputKind.classify(transportType: kAudioDeviceTransportTypeUSB, dataSourceName: nil),
            .usb)
        XCTAssertEqual(
            AudioOutputKind.classify(transportType: kAudioDeviceTransportTypeHDMI, dataSourceName: nil),
            .hdmi)
        XCTAssertEqual(
            AudioOutputKind.classify(transportType: kAudioDeviceTransportTypeDisplayPort, dataSourceName: nil),
            .display)
        XCTAssertEqual(
            AudioOutputKind.classify(transportType: kAudioDeviceTransportTypeAirPlay, dataSourceName: nil),
            .airPlay)
    }

    func testUsbEarbudsReadAsHeadphones() {
        // USB-C EarPods come through on the USB transport but should read as
        // headphones, not a bare "USB" device.
        XCTAssertEqual(
            AudioOutputKind.classify(transportType: kAudioDeviceTransportTypeUSB, deviceName: "EarPods"),
            .headphones)
        XCTAssertEqual(
            AudioOutputKind.classify(transportType: kAudioDeviceTransportTypeUSB, deviceName: "USB Audio DAC"),
            .usb)
    }

    func testUnknownTransportFallsBack() {
        XCTAssertEqual(
            AudioOutputKind.classify(transportType: kAudioDeviceTransportTypeVirtual, dataSourceName: nil),
            .other)
        XCTAssertFalse(AudioOutputKind.other.symbol.isEmpty)
        XCTAssertFalse(AudioOutputKind.other.title.isEmpty)
    }

    func testActivityReads() {
        let activity = LiveActivity.audioOutput(name: "External Headphones", kind: .headphones)

        XCTAssertEqual(activity.label, "Headphones")
        XCTAssertEqual(activity.detail, "Audio · External Headphones")
        XCTAssertEqual(activity.accessibilityLabel, "Audio output, External Headphones")
    }

    func testActivityRanksBelowDeviceEvents() {
        let audio = LiveActivity.audioOutput(name: "x", kind: .usb)
        XCTAssertLessThan(audio.priority, LiveActivity.deviceDisconnected(name: "y", kind: .other).priority)
        XCTAssertGreaterThan(audio.priority, LiveActivity.charging(percent: 50).priority)
        XCTAssertLessThanOrEqual(LiveActivity.peekDuration, audio.duration)
    }
}
