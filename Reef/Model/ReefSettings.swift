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
        static let playerTint = "playerTint"
        static let mediaSource = "mediaSource"
        static let hideMediaWhenSourceFrontmost = "media.hideWhenSourceFrontmost"
        static let swipeGestures = "gestures.swipe"
        static let naturalSwipe = "gestures.naturalDirection"
        static let weather = "weather.enabled"
        static let temperatureUnit = "weather.unit"
        static let chargingActivity = "liveActivity.charging"
        static let lowBatteryActivity = "liveActivity.lowBattery"
        static let deviceActivity = "liveActivity.devices"
        static let audioOutputActivity = "liveActivity.audioOutput"
        static let calendarActivity = "liveActivity.calendar"
        static let calendarLeadMinutes = "calendar.leadMinutes"
    }

    static let defaultOverlayStyle: OverlayStyle = .floating
    static let defaultMaterial: IslandMaterial = .liquid
    static let defaultAccent: AccentChoice = .lagoon
    static let defaultMotion: MotionStyle = .smooth
    static let defaultPlayerTint: PlayerTint = .bloom
    static let defaultMediaSource: MediaSource = .automatic

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

    /// How the open now-playing panel is colored.
    @Published var playerTint: PlayerTint {
        didSet { defaults.set(playerTint.rawValue, forKey: Key.playerTint) }
    }

    /// Which player the island follows.
    @Published var mediaSource: MediaSource {
        didSet { defaults.set(mediaSource.rawValue, forKey: Key.mediaSource) }
    }

    /// Hide the island's media while its source app is the frontmost window.
    @Published var hidesMediaWhenSourceFrontmost: Bool {
        didSet { defaults.set(hidesMediaWhenSourceFrontmost, forKey: Key.hideMediaWhenSourceFrontmost) }
    }

    /// Swipe the island to skip tracks and to open or close it.
    @Published var swipeGesturesEnabled: Bool {
        didSet { defaults.set(swipeGesturesEnabled, forKey: Key.swipeGestures) }
    }

    /// With natural direction on, swiping left moves to the next track.
    @Published var naturalSwipeDirection: Bool {
        didSet { defaults.set(naturalSwipeDirection, forKey: Key.naturalSwipe) }
    }

    /// Show local weather in the island on days with no events.
    @Published var showsWeather: Bool {
        didSet { defaults.set(showsWeather, forKey: Key.weather) }
    }

    /// Unit the weather is shown in.
    @Published var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: Key.temperatureUnit) }
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

    /// Show the wings when system audio switches to a different output.
    @Published var showsAudioOutputActivity: Bool {
        didSet { defaults.set(showsAudioOutputActivity, forKey: Key.audioOutputActivity) }
    }

    /// Show a heads-up in the wings before a calendar event starts.
    @Published var showsCalendarActivity: Bool {
        didSet { defaults.set(showsCalendarActivity, forKey: Key.calendarActivity) }
    }

    /// How many minutes before an event the heads-up appears.
    @Published var calendarLeadMinutes: Int {
        didSet { defaults.set(calendarLeadMinutes, forKey: Key.calendarLeadMinutes) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        overlayStyle = Self.value(defaults, Key.overlayStyle) ?? Self.defaultOverlayStyle
        material = Self.value(defaults, Key.material) ?? Self.defaultMaterial
        accent = Self.value(defaults, Key.accent) ?? Self.defaultAccent
        motion = Self.value(defaults, Key.motion) ?? Self.defaultMotion
        playerTint = Self.value(defaults, Key.playerTint) ?? Self.defaultPlayerTint
        mediaSource = Self.value(defaults, Key.mediaSource) ?? Self.defaultMediaSource
        hidesMediaWhenSourceFrontmost = defaults.object(forKey: Key.hideMediaWhenSourceFrontmost) as? Bool ?? false
        swipeGesturesEnabled = defaults.object(forKey: Key.swipeGestures) as? Bool ?? true
        naturalSwipeDirection = defaults.object(forKey: Key.naturalSwipe) as? Bool ?? true
        showsWeather = defaults.object(forKey: Key.weather) as? Bool ?? true
        temperatureUnit = Self.value(defaults, Key.temperatureUnit) ?? .celsius
        showsChargingActivity = defaults.object(forKey: Key.chargingActivity) as? Bool ?? true
        showsLowBatteryActivity = defaults.object(forKey: Key.lowBatteryActivity) as? Bool ?? true
        showsDeviceActivity = defaults.object(forKey: Key.deviceActivity) as? Bool ?? true
        showsAudioOutputActivity = defaults.object(forKey: Key.audioOutputActivity) as? Bool ?? true
        showsCalendarActivity = defaults.object(forKey: Key.calendarActivity) as? Bool ?? true
        calendarLeadMinutes = defaults.object(forKey: Key.calendarLeadMinutes) as? Int ?? 10
    }

    /// Put every value back to its default.
    func reset() {
        overlayStyle = Self.defaultOverlayStyle
        material = Self.defaultMaterial
        accent = Self.defaultAccent
        motion = Self.defaultMotion
        playerTint = Self.defaultPlayerTint
        mediaSource = Self.defaultMediaSource
        hidesMediaWhenSourceFrontmost = false
        swipeGesturesEnabled = true
        naturalSwipeDirection = true
        showsWeather = true
        temperatureUnit = .celsius
        showsChargingActivity = true
        showsLowBatteryActivity = true
        showsDeviceActivity = true
        showsAudioOutputActivity = true
        showsCalendarActivity = true
        calendarLeadMinutes = 10
    }

    private static func value<T: RawRepresentable>(_ defaults: UserDefaults, _ key: String) -> T?
    where T.RawValue == String {
        defaults.string(forKey: key).flatMap(T.init(rawValue:))
    }
}
