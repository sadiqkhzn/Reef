import Combine
import Foundation

/// The currently active macOS Focus, when one is on.
struct FocusStatus: Equatable {
    /// The mode identifier, e.g. `com.apple.donotdisturb.mode.work`.
    var id: String
    /// Human name, e.g. "Work" or "Do Not Disturb".
    var name: String
    /// SF Symbol the system associates with the mode, e.g. "moon.fill".
    var symbol: String
}

/// Watches which macOS Focus is active.
///
/// macOS has no public API for the current Focus, so this reads the same
/// on-disk state the system keeps in `~/Library/DoNotDisturb/DB`: the active
/// assertion names a mode identifier, and the mode configurations map that to a
/// name and symbol. Reef is not sandboxed, so it can read these files. They are
/// undocumented and can change between releases, so every read is defensive and
/// simply yields `nil` (no Focus) when anything is missing.
@MainActor
final class FocusMonitor: ObservableObject {
    @Published private(set) var current: FocusStatus?
    /// True when the Focus database exists but can't be read — the app needs
    /// Full Disk Access to see `~/Library/DoNotDisturb`.
    @Published private(set) var accessDenied = false

    private let dbDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/DoNotDisturb/DB", isDirectory: true)
    private var timer: Timer?

    func start() {
        read()
        // Poll: Focus changes are infrequent and the files are tiny, so a short
        // poll is simpler and more robust than watching files the system
        // atomically replaces.
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.read() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func read() {
        let url = dbDir.appendingPathComponent("Assertions.json")
        let exists = FileManager.default.fileExists(atPath: url.path)
        let data = try? Data(contentsOf: url)
        // The file is there but unreadable → Full Disk Access is missing.
        let denied = exists && data == nil
        if denied != accessDenied { accessDenied = denied }

        let next = denied ? nil : Self.readCurrent(in: dbDir)
        if next != current { current = next }
    }

    // MARK: - Parsing

    static func readCurrent(in dir: URL) -> FocusStatus? {
        guard let modeID = activeModeID(in: dir) else { return nil }
        let (name, symbol) = modeDetails(for: modeID, in: dir)
        return FocusStatus(id: modeID, name: name, symbol: symbol)
    }

    /// The identifier of the active Focus, or nil when none is on.
    private static func activeModeID(in dir: URL) -> String? {
        guard let json = jsonObject(at: dir.appendingPathComponent("Assertions.json")),
            let data = json["data"] as? [[String: Any]],
            let first = data.first,
            let records = first["storeAssertionRecords"] as? [[String: Any]],
            let record = records.first,
            let details = record["assertionDetails"] as? [String: Any],
            let modeID = details["assertionDetailsModeIdentifier"] as? String
        else { return nil }
        return modeID
    }

    /// The display name and symbol for a mode identifier.
    private static func modeDetails(for modeID: String, in dir: URL) -> (String, String) {
        let fallbackName = modeID.split(separator: ".").last.map {
            $0.prefix(1).uppercased() + $0.dropFirst()
        } ?? "Focus"

        guard let json = jsonObject(at: dir.appendingPathComponent("ModeConfigurations.json")),
            let data = json["data"] as? [[String: Any]],
            let first = data.first,
            let configs = first["modeConfigurations"] as? [String: Any],
            let config = configs[modeID] as? [String: Any],
            let mode = config["mode"] as? [String: Any]
        else { return (fallbackName, "moon.fill") }

        let name = (mode["name"] as? String) ?? fallbackName
        let symbol = (mode["symbolImageName"] as? String) ?? "moon.fill"
        return (name, symbol)
    }

    private static func jsonObject(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }
}
