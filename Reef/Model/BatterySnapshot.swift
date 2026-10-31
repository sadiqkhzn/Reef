import Foundation

/// A plain reading of the Mac's battery at one moment.
struct BatterySnapshot: Equatable {
    /// False when the machine has no battery, such as a desktop Mac.
    var isPresent: Bool
    /// Charge from 0 to 100.
    var percent: Int
    /// True while the battery is actively charging.
    var isCharging: Bool
    /// True while running on wall power, whether or not it is charging.
    var isPluggedIn: Bool
    /// Minutes until empty on battery, when the system has an estimate. Nil while
    /// it is still calculating or on wall power.
    var minutesToEmpty: Int? = nil
    /// Minutes until full while charging, when the system has an estimate. Nil
    /// while it is still calculating or not charging.
    var minutesToFull: Int? = nil

    /// A reading for a machine with no battery.
    static let absent = BatterySnapshot(
        isPresent: false, percent: 0, isCharging: false, isPluggedIn: false)

    /// Build a snapshot from a power source description dictionary.
    ///
    /// The keys are the ones IOKit uses for a power source. They are spelled out
    /// here as plain strings so this stays free of IOKit and can be tested with
    /// hand-built dictionaries.
    static func parse(_ description: [String: Any]) -> BatterySnapshot {
        let current = (description["Current Capacity"] as? Int)
        let max = (description["Max Capacity"] as? Int) ?? 100
        let charging = (description["Is Charging"] as? Bool) ?? false
        let state = (description["Power Source State"] as? String)

        guard let current, max > 0 else {
            return .absent
        }

        let raw = Double(current) / Double(max) * 100
        let percent = Swift.min(100, Swift.max(0, Int(raw.rounded())))

        // The system reports -1 (and sometimes a very large placeholder) while it
        // is still working out an estimate; treat those as "no estimate yet".
        func minutes(_ key: String) -> Int? {
            guard let value = description[key] as? Int, value > 0, value < 60 * 48 else {
                return nil
            }
            return value
        }

        return BatterySnapshot(
            isPresent: true,
            percent: percent,
            isCharging: charging,
            isPluggedIn: state == "AC Power",
            minutesToEmpty: minutes("Time to Empty"),
            minutesToFull: minutes("Time to Full Charge"))
    }

    /// A short "time left" phrase for the current state, or nil when there is no
    /// estimate (fully charged, holding charge, or still calculating).
    var timeEstimateText: String? {
        let minutes: Int?
        switch status {
        case .charging: minutes = minutesToFull
        case .onBattery: minutes = minutesToEmpty
        case .fullyCharged, .notCharging: minutes = nil
        }
        guard let minutes else { return nil }
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}

extension BatterySnapshot {
    /// What the power state means in words, for the open island.
    enum Status: Equatable {
        case charging
        case fullyCharged
        /// On wall power but holding its charge, as macOS does with optimized
        /// charging.
        case notCharging
        case onBattery
    }

    var status: Status {
        if isCharging { return .charging }
        if isPluggedIn { return percent >= 100 ? .fullyCharged : .notCharging }
        return .onBattery
    }
}

extension BatterySnapshot.Status {
    var title: String {
        switch self {
        case .charging: return "Charging"
        case .fullyCharged: return "Fully charged"
        case .notCharging: return "Not charging"
        case .onBattery: return "On battery"
        }
    }
}
