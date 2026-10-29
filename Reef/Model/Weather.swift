import Foundation

/// Temperature unit the forecast is requested and shown in.
enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius
    case fahrenheit

    var id: String { rawValue }

    /// The value Open-Meteo expects for `temperature_unit`.
    var apiValue: String { rawValue }

    var title: String {
        switch self {
        case .celsius: return "Celsius"
        case .fahrenheit: return "Fahrenheit"
        }
    }
}

/// A sky condition, mapped from a WMO weather code, with a symbol and a label.
enum WeatherCondition: Equatable {
    case clear
    case partlyCloudy
    case cloudy
    case fog
    case drizzle
    case rain
    case snow
    case showers
    case thunderstorm

    /// Map a WMO weather code (as Open-Meteo reports) to a condition.
    init(wmoCode code: Int) {
        switch code {
        case 0: self = .clear
        case 1, 2: self = .partlyCloudy
        case 3: self = .cloudy
        case 45, 48: self = .fog
        case 51, 53, 55, 56, 57: self = .drizzle
        case 61, 63, 65, 66, 67: self = .rain
        case 71, 73, 75, 77: self = .snow
        case 80, 81, 82: self = .showers
        case 85, 86: self = .snow
        case 95, 96, 99: self = .thunderstorm
        default: self = .cloudy
        }
    }

    var label: String {
        switch self {
        case .clear: return "Clear"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy: return "Cloudy"
        case .fog: return "Fog"
        case .drizzle: return "Drizzle"
        case .rain: return "Rain"
        case .snow: return "Snow"
        case .showers: return "Showers"
        case .thunderstorm: return "Thunderstorm"
        }
    }

    /// SF Symbol for the condition. The daytime variants read fine on the dark
    /// island whatever the hour.
    var symbol: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .fog: return "cloud.fog.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .showers: return "cloud.heavyrain.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        }
    }
}

/// A snapshot of the current weather for the place the Mac is in.
struct WeatherSnapshot: Equatable {
    var temperature: Double
    var high: Double?
    var low: Double?
    var condition: WeatherCondition
    var unit: TemperatureUnit

    /// The current temperature as a whole number with a degree sign, e.g. "12°".
    var temperatureText: String { Self.degrees(temperature) }
    var highText: String? { high.map(Self.degrees) }
    var lowText: String? { low.map(Self.degrees) }

    static func degrees(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }

    /// Build a snapshot from an Open-Meteo forecast response.
    static func decode(_ data: Data, unit: TemperatureUnit) throws -> WeatherSnapshot {
        let response = try JSONDecoder().decode(Response.self, from: data)
        return WeatherSnapshot(
            temperature: response.current.temperature_2m,
            high: response.daily?.temperature_2m_max.first,
            low: response.daily?.temperature_2m_min.first,
            condition: WeatherCondition(wmoCode: response.current.weather_code),
            unit: unit)
    }

    /// The slice of the Open-Meteo response Reef reads.
    private struct Response: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
        }
        struct Daily: Decodable {
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
        }
        let current: Current
        let daily: Daily?
    }
}
