import Combine
import Foundation

/// The person's choices, kept in user defaults.
///
/// Each value is published so the overlay and the settings window update the
/// moment something changes. Unknown or missing stored values fall back to the
/// defaults below, so a newer build can drop or rename a case without leaving
/// the app in a broken state.
final class ReefSettings: ObservableObject {

    enum Key {
        static let overlayStyle = "overlayStyle"
        static let material = "islandMaterial"
        static let accent = "accent"
        static let motion = "motionStyle"
        static let chargingActivity = "liveActivity.charging"
        static let lowBatteryActivity = "liveActivity.lowBattery"
        static let deviceActivity = "liveActivity.devices"
    }

    static let defaultOverlayStyle: OverlayStyle = .floating
    static let defaultMaterial: IslandMaterial = .liquid
    static let defaultAccent: AccentChoice = .lagoon
    static let defaultMotion: MotionStyle = .smooth

    @Published var overlayStyle: OverlayStyle {
        didSet { defaults.set(overlayStyle.rawValue, forKey: Key.overlayStyle) }
    }

    @Published var material: IslandMaterial {
        didSet { defaults.set(material.rawValue, forKey: Key.material) }
    }

    @Published var accent: AccentChoice {
        didSet { defaults.set(accent.rawValue, forKey: Key.accent) }
    }

    @Published var motion: MotionStyle {
        didSet { defaults.set(motion.rawValue, forKey: Key.motion) }
    }

    /// Show the wings when power is connected or the battery finishes charging.
    @Published var showsChargingActivity: Bool {
        didSet { defaults.set(showsChargingActivity, forKey: Key.chargingActivity) }
    }

    /// Show the wings when the battery runs low.
    @Published var showsLowBatteryActivity: Bool {
        didSet { defaults.set(showsLowBatteryActivity, forKey: Key.lowBatteryActivity) }
    }

    /// Show the wings when headphones or another Bluetooth device connects.
    @Published var showsDeviceActivity: Bool {
        didSet { defaults.set(showsDeviceActivity, forKey: Key.deviceActivity) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        overlayStyle = Self.value(defaults, Key.overlayStyle) ?? Self.defaultOverlayStyle
        material = Self.value(defaults, Key.material) ?? Self.defaultMaterial
        accent = Self.value(defaults, Key.accent) ?? Self.defaultAccent
        motion = Self.value(defaults, Key.motion) ?? Self.defaultMotion
        showsChargingActivity = defaults.object(forKey: Key.chargingActivity) as? Bool ?? true
        showsLowBatteryActivity = defaults.object(forKey: Key.lowBatteryActivity) as? Bool ?? true
        showsDeviceActivity = defaults.object(forKey: Key.deviceActivity) as? Bool ?? true
    }

    /// Put every value back to its default.
    func reset() {
        overlayStyle = Self.defaultOverlayStyle
        material = Self.defaultMaterial
        accent = Self.defaultAccent
        motion = Self.defaultMotion
        showsChargingActivity = true
        showsLowBatteryActivity = true
        showsDeviceActivity = true
    }

    private static func value<T: RawRepresentable>(_ defaults: UserDefaults, _ key: String) -> T?
    where T.RawValue == String {
        defaults.string(forKey: key).flatMap(T.init(rawValue:))
    }
}
