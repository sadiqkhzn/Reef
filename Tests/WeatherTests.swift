import CoreLocation
import XCTest
@testable import Reef

/// Covers the WMO code mapping, temperature formatting, and decoding the
/// Open-Meteo response.
final class WeatherTests: XCTestCase {

    func testWeatherCodeMapping() {
        XCTAssertEqual(WeatherCondition(wmoCode: 0), .clear)
        XCTAssertEqual(WeatherCondition(wmoCode: 2), .partlyCloudy)
        XCTAssertEqual(WeatherCondition(wmoCode: 3), .cloudy)
        XCTAssertEqual(WeatherCondition(wmoCode: 48), .fog)
        XCTAssertEqual(WeatherCondition(wmoCode: 63), .rain)
        XCTAssertEqual(WeatherCondition(wmoCode: 75), .snow)
        XCTAssertEqual(WeatherCondition(wmoCode: 81), .showers)
        XCTAssertEqual(WeatherCondition(wmoCode: 95), .thunderstorm)
    }

    func testUnknownCodeFallsBackToCloudy() {
        XCTAssertEqual(WeatherCondition(wmoCode: 1234), .cloudy)
    }

    func testEveryConditionHasSymbolAndLabel() {
        for code in 0...99 {
            let condition = WeatherCondition(wmoCode: code)
            XCTAssertFalse(condition.symbol.isEmpty)
            XCTAssertFalse(condition.label.isEmpty)
        }
    }

    func testTemperatureFormatting() {
        XCTAssertEqual(WeatherSnapshot.degrees(12.3), "12°")
        XCTAssertEqual(WeatherSnapshot.degrees(12.7), "13°")
        XCTAssertEqual(WeatherSnapshot.degrees(-0.4), "0°")
    }

    func testDecodeFullResponse() throws {
        let json = """
        {
          "current": { "temperature_2m": 14.6, "weather_code": 61 },
          "daily": {
            "temperature_2m_max": [18.2],
            "temperature_2m_min": [9.1]
          }
        }
        """.data(using: .utf8)!

        let snapshot = try WeatherSnapshot.decode(json, unit: .celsius)
        XCTAssertEqual(snapshot.temperature, 14.6, accuracy: 0.001)
        XCTAssertEqual(snapshot.high, 18.2)
        XCTAssertEqual(snapshot.low, 9.1)
        XCTAssertEqual(snapshot.condition, .rain)
        XCTAssertEqual(snapshot.temperatureText, "15°")
        XCTAssertEqual(snapshot.highText, "18°")
        XCTAssertEqual(snapshot.lowText, "9°")
    }

    func testForecastURLRoundsCoordinateAndCarriesUnit() throws {
        let coordinate = CLLocationCoordinate2D(latitude: 28.613939, longitude: 77.209021)
        let url = try XCTUnwrap(WeatherProvider.forecastURL(for: coordinate, unit: .fahrenheit))
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value) })

        XCTAssertEqual(url.host, "api.open-meteo.com")
        XCTAssertEqual(values["latitude"], "28.61", "coordinate is coarsened to ~1km")
        XCTAssertEqual(values["longitude"], "77.21")
        XCTAssertEqual(values["temperature_unit"], "fahrenheit")
    }

    func testDecodeWithoutDaily() throws {
        let json = """
        { "current": { "temperature_2m": 20.0, "weather_code": 0 } }
        """.data(using: .utf8)!

        let snapshot = try WeatherSnapshot.decode(json, unit: .fahrenheit)
        XCTAssertEqual(snapshot.temperature, 20.0)
        XCTAssertNil(snapshot.high)
        XCTAssertNil(snapshot.low)
        XCTAssertEqual(snapshot.condition, .clear)
    }
}
