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

/// One hour of the forecast.
struct HourForecast: Equatable, Identifiable {
    let date: Date
    let temperature: Double
    let condition: WeatherCondition
    var id: Date { date }
    var temperatureText: String { WeatherSnapshot.degrees(temperature) }
}

/// One day of the forecast.
struct DayForecast: Equatable, Identifiable {
    let date: Date
    let high: Double
    let low: Double
    let condition: WeatherCondition
    var id: Date { date }
    var highText: String { WeatherSnapshot.degrees(high) }
    var lowText: String { WeatherSnapshot.degrees(low) }
}

/// The upcoming hours and days, for the weather page.
struct WeatherForecast: Equatable {
    var hours: [HourForecast]
    var days: [DayForecast]

    /// The next `count` hours from now, inclusive of the current hour.
    func upcomingHours(from now: Date = Date(), count: Int = 8) -> [HourForecast] {
        let hourStart = Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: now),
            minute: 0, second: 0, of: now) ?? now
        return Array(hours.filter { $0.date >= hourStart }.prefix(count))
    }

    /// The upcoming days, skipping today.
    func upcomingDays(from now: Date = Date(), count: Int = 4) -> [DayForecast] {
        let today = Calendar.current.startOfDay(for: now)
        return Array(days.filter { $0.date > today }.prefix(count))
    }

    /// Build a forecast from an Open-Meteo response carrying hourly and daily
    /// arrays with their time stamps. Returns nil when the arrays are missing.
    static func decode(_ data: Data) -> WeatherForecast? {
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            return nil
        }
        let parse = Self.timeParser()

        var hours: [HourForecast] = []
        if let hourly = response.hourly {
            for (index, stamp) in hourly.time.enumerated()
            where index < hourly.temperature_2m.count && index < hourly.weather_code.count {
                guard let date = parse(stamp) else { continue }
                hours.append(HourForecast(
                    date: date,
                    temperature: hourly.temperature_2m[index],
                    condition: WeatherCondition(wmoCode: hourly.weather_code[index])))
            }
        }

        var days: [DayForecast] = []
        if let daily = response.daily, let times = daily.time {
            for (index, stamp) in times.enumerated()
            where index < daily.temperature_2m_max.count
                && index < daily.temperature_2m_min.count
                && index < (daily.weather_code?.count ?? 0) {
                guard let date = parse(stamp) else { continue }
                days.append(DayForecast(
                    date: date,
                    high: daily.temperature_2m_max[index],
                    low: daily.temperature_2m_min[index],
                    condition: WeatherCondition(wmoCode: daily.weather_code?[index] ?? 0)))
            }
        }

        guard !hours.isEmpty || !days.isEmpty else { return nil }
        return WeatherForecast(hours: hours, days: days)
    }

    /// A parser for Open-Meteo's local-time stamps ("2026-11-01T14:00" for hours,
    /// "2026-11-01" for days), read in the current time zone.
    private static func timeParser() -> (String) -> Date? {
        let hourly = DateFormatter()
        hourly.locale = Locale(identifier: "en_US_POSIX")
        hourly.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let daily = DateFormatter()
        daily.locale = Locale(identifier: "en_US_POSIX")
        daily.dateFormat = "yyyy-MM-dd"
        return { stamp in hourly.date(from: stamp) ?? daily.date(from: stamp) }
    }

    /// The slice of the Open-Meteo response the forecast reads.
    private struct Response: Decodable {
        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m: [Double]
            let weather_code: [Int]
        }
        struct Daily: Decodable {
            let time: [String]?
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let weather_code: [Int]?
        }
        let hourly: Hourly?
        let daily: Daily?
    }
}
