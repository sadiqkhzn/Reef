import AppKit
import Combine
import Foundation

/// Publishes a small snapshot of what Reef knows (playing track, weather,
/// battery) to a file the lock-screen widget plugin can read.
///
/// The widget runs inside the SecurityAgent process, a separate security context
/// that cannot see Reef's in-memory state, so the two sides share a plain JSON
/// file. Reef only writes it when the shared directory exists, which the lock
/// widget's installer creates — so with the widget not installed, this does
/// nothing and leaves no files behind.
@MainActor
final class LockWidgetBridge {
    /// Directory the installer creates (writable by the user, readable by the
    /// widget running as root).
    static let directoryPath = "/Library/Application Support/Reef"
    static let filePath = directoryPath + "/lockscreen.json"

    private let media: NowPlayingController
    private let weather: WeatherProvider
    private let battery: BatteryModel
    private var cancellables: Set<AnyCancellable> = []

    init(media: NowPlayingController, weather: WeatherProvider, battery: BatteryModel) {
        self.media = media
        self.weather = weather
        self.battery = battery
    }

    func start() {
        write()
        media.$current
            .sink { [weak self] _ in self?.write() }
            .store(in: &cancellables)
        weather.$snapshot
            .sink { [weak self] _ in self?.write() }
            .store(in: &cancellables)
        battery.$snapshot
            .sink { [weak self] _ in self?.write() }
            .store(in: &cancellables)
    }

    /// Serialize the current snapshot. Pure, so it can be tested.
    nonisolated static func snapshotJSON(
        track: NowPlaying?, weather: WeatherSnapshot?, battery: BatterySnapshot
    ) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let track {
            dict["nowPlaying"] = [
                "title": track.title,
                "artist": track.artist,
                "isPlaying": track.isPlaying,
            ]
        }
        if let weather {
            dict["weather"] = [
                "temp": weather.temperatureText,
                "condition": weather.condition.label,
                "symbol": weather.condition.symbol,
            ]
        }
        if battery.isPresent {
            dict["battery"] = [
                "percent": battery.percent,
                "charging": battery.isCharging,
            ]
        }
        return dict
    }

    private func write() {
        // Only share when the widget's directory is present, so Reef writes
        // nothing unless the lock widget has been installed.
        guard FileManager.default.fileExists(atPath: Self.directoryPath) else { return }
        let dict = Self.snapshotJSON(
            track: media.current, weather: weather.snapshot, battery: battery.snapshot)
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
            return
        }
        try? data.write(to: URL(fileURLWithPath: Self.filePath), options: .atomic)
    }
}
