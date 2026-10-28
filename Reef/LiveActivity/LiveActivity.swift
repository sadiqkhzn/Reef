import Foundation

/// A short, glanceable state the resting island shows in its wings, without
/// opening.
///
/// Only one activity shows at a time. When a new one arrives while another is
/// still on screen, the one with the higher priority wins.
enum LiveActivity: Equatable {
    /// Power was just connected and the battery is charging.
    case charging(percent: Int)
    /// The battery reached full charge while on wall power.
    case fullyCharged
    /// The battery crossed a low threshold while on battery power.
    case lowBattery(percent: Int, isCritical: Bool)

    /// Higher wins when two activities compete for the wings.
    var priority: Int {
        switch self {
        case .lowBattery(_, let isCritical): return isCritical ? 30 : 20
        case .charging: return 10
        case .fullyCharged: return 5
        }
    }

    /// How long the activity stays before the wings fold away.
    var duration: TimeInterval {
        switch self {
        case .charging, .fullyCharged: return 4
        case .lowBattery: return 6
        }
    }

    /// Short text shown between the wings when there is no hardware notch in
    /// the way.
    var label: String {
        switch self {
        case .charging: return "Charging"
        case .fullyCharged: return "Fully charged"
        case .lowBattery(_, let isCritical): return isCritical ? "Battery critical" : "Low battery"
        }
    }

    /// Spoken by VoiceOver for the collapsed wings.
    var accessibilityLabel: String {
        switch self {
        case .charging(let percent): return "Charging, \(percent) percent"
        case .fullyCharged: return "Battery fully charged"
        case .lowBattery(let percent, _): return "\(label), \(percent) percent"
        }
    }
}

/// Decides which battery activity, if any, a change in power state deserves.
///
/// Pure, so the rules can be tested without a battery.
enum BatteryActivityPolicy {
    /// At or below this, while on battery, the low-battery warning shows.
    static let lowThreshold = 20
    /// At or below this, the warning escalates to critical.
    static let criticalThreshold = 10

    static func activity(from old: BatterySnapshot, to new: BatterySnapshot) -> LiveActivity? {
        guard new.isPresent else { return nil }

        // Plugging in.
        if !old.isPluggedIn && new.isPluggedIn {
            if new.isCharging || new.percent < 100 {
                return .charging(percent: new.percent)
            }
            return .fullyCharged
        }

        // Finishing a charge on wall power.
        if new.isPluggedIn {
            if old.percent < 100 && new.percent >= 100 {
                return .fullyCharged
            }
            return nil
        }

        // Draining on battery: warn once per threshold, on the way down.
        if old.percent > criticalThreshold && new.percent <= criticalThreshold {
            return .lowBattery(percent: new.percent, isCritical: true)
        }
        if old.percent > lowThreshold && new.percent <= lowThreshold {
            return .lowBattery(percent: new.percent, isCritical: false)
        }
        return nil
    }
}
