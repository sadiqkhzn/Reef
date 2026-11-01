import XCTest
@testable import Reef

/// Covers the pure parts of the ambient display: the idle rule and the clock
/// formatting. The window, idle polling, and input watching need a live session,
/// so only the interpretation is tested here.
final class AmbientTests: XCTestCase {

    // MARK: - Idle rule

    func testIdleAtThresholdCountsAsIdle() {
        XCTAssertTrue(IdleDecision.isIdle(seconds: 300, threshold: 300))
    }

    func testBelowThresholdIsNotIdle() {
        XCTAssertFalse(IdleDecision.isIdle(seconds: 299, threshold: 300))
    }

    func testWellPastThresholdIsIdle() {
        XCTAssertTrue(IdleDecision.isIdle(seconds: 1000, threshold: 120))
    }

    // MARK: - Clock

    private func date(hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.day = 1
        comps.hour = hour
        comps.minute = minute
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    func testTimeTextCarriesTheMinutes() {
        // The 12- vs 24-hour shape is locale-dependent, but the minutes are
        // always present.
        XCTAssertTrue(AmbientClock.timeText(date(hour: 9, minute: 41)).contains("41"))
    }

    func testTwentyFourHourLocaleShowsThirteen() {
        // A 24-hour locale renders 1 PM as 13.
        let text = AmbientClock.timeText(date(hour: 13, minute: 5), locale: Locale(identifier: "en_GB"))
        XCTAssertTrue(text.contains("13"))
    }

    func testDateTextIsNotEmptyAndNamesTheMonth() {
        let text = AmbientClock.dateText(date(hour: 9, minute: 41), locale: Locale(identifier: "en_US"))
        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(text.contains("November"))
    }

    // MARK: - Lock widget bridge

    func testBridgeJSONCarriesEachSection() {
        let track = NowPlaying(title: "Song", artist: "Artist", album: "", isPlaying: true)
        let weather = WeatherSnapshot(
            temperature: 12, high: 15, low: 8, condition: .clear, unit: .celsius)
        let battery = BatterySnapshot(
            isPresent: true, percent: 80, isCharging: true, isPluggedIn: true)

        let json = LockWidgetBridge.snapshotJSON(track: track, weather: weather, battery: battery)

        let playing = json["nowPlaying"] as? [String: Any]
        XCTAssertEqual(playing?["title"] as? String, "Song")
        XCTAssertEqual(playing?["isPlaying"] as? Bool, true)
        XCTAssertEqual((json["weather"] as? [String: Any])?["temp"] as? String, "12°")
        XCTAssertEqual((json["battery"] as? [String: Any])?["percent"] as? Int, 80)
    }

    func testBridgeJSONOmitsAbsentBatteryAndNilSources() {
        let json = LockWidgetBridge.snapshotJSON(
            track: nil, weather: nil, battery: .absent)
        XCTAssertNil(json["nowPlaying"])
        XCTAssertNil(json["weather"])
        XCTAssertNil(json["battery"])
    }
}
