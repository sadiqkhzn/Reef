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

        return BatterySnapshot(
            isPresent: true,
            percent: percent,
            isCharging: charging,
            isPluggedIn: state == "AC Power")
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
