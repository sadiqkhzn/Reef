import CoreLocation
import Foundation

/// Keeps the current weather for wherever the Mac is.
///
/// It gets a coarse location, asks Open-Meteo (a free service that needs no key)
/// for the current conditions and today's high and low, and refreshes on a slow
/// timer. Only the coordinate leaves the Mac, and only to fetch the forecast.
@MainActor
final class WeatherProvider: ObservableObject {
    @Published private(set) var snapshot: WeatherSnapshot?
    /// The upcoming hours and days, for the weather page.
    @Published private(set) var forecast: WeatherForecast?
    @Published private(set) var accessDenied = false

    /// Unit to request and show in. Changing it refetches.
    var unit: TemperatureUnit = .celsius {
        didSet {
            guard oldValue != unit else { return }
            Task { await refetch() }
        }
    }

    private let location = LocationProvider()
    private var timer: Timer?
    private var lastCoordinate: CLLocationCoordinate2D?
    private var started = false

    func start() {
        guard !started else { return }
        started = true

        location.onUpdate = { [weak self] coordinate in
            Task { @MainActor in await self?.fetch(coordinate) }
        }
        location.onDenied = { [weak self] in
            Task { @MainActor in self?.accessDenied = true }
        }
        location.start()

        // Refresh every 30 minutes by asking for a fresh fix, which fetches.
        let timer = Timer(timeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.location.requestOnce() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        started = false
    }

    private func refetch() async {
        guard let coordinate = lastCoordinate else { return }
        await fetch(coordinate)
    }

    private func fetch(_ coordinate: CLLocationCoordinate2D) async {
        lastCoordinate = coordinate
        accessDenied = false
        guard let url = Self.forecastURL(for: coordinate, unit: unit) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            snapshot = try WeatherSnapshot.decode(data, unit: unit)
            if let forecast = WeatherForecast.decode(data) { self.forecast = forecast }
        } catch {
            // Keep the last good snapshot on a network or decode hiccup.
        }
    }

    /// Build the Open-Meteo request for a coordinate, rounded to about a
    /// kilometer so an exact position never goes over the wire.
    nonisolated static func forecastURL(
        for coordinate: CLLocationCoordinate2D, unit: TemperatureUnit
    ) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code"),
            URLQueryItem(
                name: "daily",
                value: "temperature_2m_max,temperature_2m_min,weather_code"),
            URLQueryItem(name: "temperature_unit", value: unit.apiValue),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "6"),
        ]
        return components?.url
    }
}
