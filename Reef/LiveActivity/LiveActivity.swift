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
    /// A Bluetooth device such as AirPods just connected.
    case deviceConnected(name: String, kind: DeviceKind)

    /// Higher wins when two activities compete for the wings.
    var priority: Int {
        switch self {
        case .lowBattery(_, let isCritical): return isCritical ? 30 : 20
        case .deviceConnected: return 15
        case .charging: return 10
        case .fullyCharged: return 5
        }
    }

    /// How long the activity stays before the wings fold away.
    var duration: TimeInterval {
        switch self {
        case .charging, .fullyCharged: return 4
        case .deviceConnected: return 3.5
        case .lowBattery: return 6
        }
    }

    /// How long the quick peek, the second line of detail under the wings,
    /// shows when the activity arrives.
    static let peekDuration: TimeInterval = 2

    /// Short text shown between the wings when there is no hardware notch in
    /// the way.
    var label: String {
        switch self {
        case .charging: return "Charging"
        case .fullyCharged: return "Fully charged"
        case .lowBattery(_, let isCritical): return isCritical ? "Battery critical" : "Low battery"
        case .deviceConnected: return "Connected"
        }
    }

    /// The line of detail shown in the quick peek.
    var detail: String {
        switch self {
        case .charging(let percent): return "Charging · \(percent)%"
        case .fullyCharged: return "Battery fully charged"
        case .lowBattery(let percent, let isCritical):
            return isCritical ? "Battery critical · Plug in soon" : "Low battery · \(percent)% left"
        case .deviceConnected(let name, _): return "\(name) · Connected"
        }
    }

    /// Spoken by VoiceOver for the collapsed wings.
    var accessibilityLabel: String {
        switch self {
        case .charging(let percent): return "Charging, \(percent) percent"
        case .fullyCharged: return "Battery fully charged"
        case .lowBattery(let percent, _): return "\(label), \(percent) percent"
        case .deviceConnected(let name, _): return "\(name) connected"
        }
    }
}

/// The kind of Bluetooth device, guessed from its name, so the wings can show
/// a fitting symbol.
enum DeviceKind: Equatable {
    case airpods
    case airpodsPro
    case airpodsMax
    case beats
    case headphones
    case keyboard
    case mouse
    case trackpad
    case gameController
    case other

    /// Guess the kind from the name the device advertises, such as
    /// "Sadiq's AirPods Pro" or "Magic Keyboard". Unknown names fall back to
    /// `.other`.
    init(name: String) {
        let n = name.lowercased()
        func has(_ words: String...) -> Bool { words.contains { n.contains($0) } }
        if has("airpods max") { self = .airpodsMax }
        else if has("airpods pro") { self = .airpodsPro }
        else if has("airpods") { self = .airpods }
        else if has("beats", "powerbeats") { self = .beats }
        else if has("headphone", "buds", "bose", "sony wh", "wh-1000", "headset") { self = .headphones }
        else if has("keyboard") { self = .keyboard }
        else if has("trackpad") { self = .trackpad }
        else if has("mouse") { self = .mouse }
        else if has("controller", "dualsense", "dualshock", "xbox") { self = .gameController }
        else { self = .other }
    }

    /// SF Symbol for the leading wing.
    var symbol: String {
        switch self {
        case .airpods: return "airpods"
        case .airpodsPro: return "airpodspro"
        case .airpodsMax: return "airpodsmax"
        case .beats: return "beats.headphones"
        case .headphones: return "headphones"
        case .keyboard: return "keyboard"
        case .mouse: return "magicmouse"
        case .trackpad: return "hand.point.up.left"
        case .gameController: return "gamecontroller"
        case .other: return "dot.radiowaves.left.and.right"
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
