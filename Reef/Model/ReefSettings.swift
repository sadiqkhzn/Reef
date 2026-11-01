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
        static let liveWaveform = "nowPlaying.liveWaveform"
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
        static let eventAtRest = "calendar.eventAtRest"
        static let hiddenCalendars = "calendar.hidden"
        static let lowBatteryThreshold = "battery.lowThreshold"
        static let lowPowerModeActivity = "liveActivity.lowPowerMode"
        static let replaceVolumeHUD = "hud.replaceVolume"
        static let replaceBrightnessHUD = "hud.replaceBrightness"
        static let hudSound = "hud.sound"
        static let hideBatteryPercentage = "battery.hidePercentage"
        static let opensOnHover = "open.onHover"
        static let hoverOpenSeconds = "open.hoverSeconds"
        static let quickPeek = "open.quickPeek"
        static let displayTarget = "displayTarget"
        static let simulatedNotch = "notch.simulated"
        static let simulatedNotchWidth = "notch.simulatedWidth"
        static let simulatedNotchHeight = "notch.simulatedHeight"
        static let hideFromCapture = "privacy.hideFromCapture"
        static let keepAwake = "power.keepAwake"
        static let contrastOutline = "appearance.contrastOutline"
        static let haptics = "appearance.haptics"
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

    /// Draw a clear outline around the island for legibility.
    @Published var contrastOutline: Bool {
        didSet { defaults.set(contrastOutline, forKey: Key.contrastOutline) }
    }

    /// Give a small haptic tap on the trackpad when the island opens or closes.
    @Published var haptics: Bool {
        didSet { defaults.set(haptics, forKey: Key.haptics) }
    }

    /// Keep the island out of screenshots and screen recordings.
    @Published var hideFromScreenCapture: Bool {
        didSet { defaults.set(hideFromScreenCapture, forKey: Key.hideFromCapture) }
    }

    /// Keep the Mac and its display from sleeping.
    @Published var keepAwake: Bool {
        didSet { defaults.set(keepAwake, forKey: Key.keepAwake) }
    }

    /// How the open now-playing panel is colored.
    @Published var playerTint: PlayerTint {
        didSet { defaults.set(playerTint.rawValue, forKey: Key.playerTint) }
    }

    /// Drive the equalizer from the real system audio instead of a canned motion.
    @Published var useLiveWaveform: Bool {
        didSet { defaults.set(useLiveWaveform, forKey: Key.liveWaveform) }
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

    /// Percent at which the low-battery warning shows.
    @Published var lowBatteryThreshold: Int {
        didSet { defaults.set(lowBatteryThreshold, forKey: Key.lowBatteryThreshold) }
    }

    /// Show the wings when Low Power Mode turns on.
    @Published var showsLowPowerModeActivity: Bool {
        didSet { defaults.set(showsLowPowerModeActivity, forKey: Key.lowPowerModeActivity) }
    }

    /// Replace the system volume overlay with Reef's HUD in the notch when the
    /// volume keys are pressed. Needs Accessibility permission to take effect.
    @Published var replacesVolumeHUD: Bool {
        didSet { defaults.set(replacesVolumeHUD, forKey: Key.replaceVolumeHUD) }
    }

    /// Replace the system brightness overlay with Reef's HUD. Needs Accessibility
    /// permission, and a display that supports software brightness.
    @Published var replacesBrightnessHUD: Bool {
        didSet { defaults.set(replacesBrightnessHUD, forKey: Key.replaceBrightnessHUD) }
    }

    /// Play a short click when the volume changes through Reef's HUD.
    @Published var hudPlaysSound: Bool {
        didSet { defaults.set(hudPlaysSound, forKey: Key.hudSound) }
    }

    /// Hide the battery number on the badge and the home card.
    @Published var hidesBatteryPercentage: Bool {
        didSet { defaults.set(hidesBatteryPercentage, forKey: Key.hideBatteryPercentage) }
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

    /// Show the next event on the resting island while nothing is playing.
    @Published var showsEventAtRest: Bool {
        didSet { defaults.set(showsEventAtRest, forKey: Key.eventAtRest) }
    }

    /// Identifiers of calendars to leave out. Empty shows them all.
    @Published var hiddenCalendarIDs: Set<String> {
        didSet { defaults.set(Array(hiddenCalendarIDs), forKey: Key.hiddenCalendars) }
    }

    /// Open the island by hovering it, not only by clicking.
    @Published var opensOnHover: Bool {
        didSet { defaults.set(opensOnHover, forKey: Key.opensOnHover) }
    }

    /// How long to dwell before a hover opens the island.
    @Published var hoverOpenSeconds: Double {
        didSet { defaults.set(hoverOpenSeconds, forKey: Key.hoverOpenSeconds) }
    }

    /// Grow the island a touch the moment the pointer arrives.
    @Published var quickPeek: Bool {
        didSet { defaults.set(quickPeek, forKey: Key.quickPeek) }
    }

    /// Which display the island appears on.
    @Published var displayTarget: DisplayTarget {
        didSet { defaults.set(displayTarget.rawValue, forKey: Key.displayTarget) }
    }

    /// Draw a simulated notch on Macs that have none, in the attached style.
    @Published var simulatedNotch: Bool {
        didSet { defaults.set(simulatedNotch, forKey: Key.simulatedNotch) }
    }

    /// Width of the simulated notch.
    @Published var simulatedNotchWidth: Double {
        didSet { defaults.set(simulatedNotchWidth, forKey: Key.simulatedNotchWidth) }
    }

    /// Height of the simulated notch.
    @Published var simulatedNotchHeight: Double {
        didSet { defaults.set(simulatedNotchHeight, forKey: Key.simulatedNotchHeight) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        overlayStyle = Self.value(defaults, Key.overlayStyle) ?? Self.defaultOverlayStyle
        material = Self.value(defaults, Key.material) ?? Self.defaultMaterial
        accent = Self.value(defaults, Key.accent) ?? Self.defaultAccent
        motion = Self.value(defaults, Key.motion) ?? Self.defaultMotion
        contrastOutline = defaults.object(forKey: Key.contrastOutline) as? Bool ?? false
        haptics = defaults.object(forKey: Key.haptics) as? Bool ?? false
        hideFromScreenCapture = defaults.object(forKey: Key.hideFromCapture) as? Bool ?? false
        keepAwake = defaults.object(forKey: Key.keepAwake) as? Bool ?? false
        playerTint = Self.value(defaults, Key.playerTint) ?? Self.defaultPlayerTint
        useLiveWaveform = defaults.object(forKey: Key.liveWaveform) as? Bool ?? false
        mediaSource = Self.value(defaults, Key.mediaSource) ?? Self.defaultMediaSource
        hidesMediaWhenSourceFrontmost = defaults.object(forKey: Key.hideMediaWhenSourceFrontmost) as? Bool ?? false
        swipeGesturesEnabled = defaults.object(forKey: Key.swipeGestures) as? Bool ?? true
        naturalSwipeDirection = defaults.object(forKey: Key.naturalSwipe) as? Bool ?? true
        showsWeather = defaults.object(forKey: Key.weather) as? Bool ?? true
        temperatureUnit = Self.value(defaults, Key.temperatureUnit) ?? .celsius
        showsChargingActivity = defaults.object(forKey: Key.chargingActivity) as? Bool ?? true
        showsLowBatteryActivity = defaults.object(forKey: Key.lowBatteryActivity) as? Bool ?? true
        lowBatteryThreshold = defaults.object(forKey: Key.lowBatteryThreshold) as? Int ?? 20
        showsLowPowerModeActivity = defaults.object(forKey: Key.lowPowerModeActivity) as? Bool ?? true
        replacesVolumeHUD = defaults.object(forKey: Key.replaceVolumeHUD) as? Bool ?? false
        replacesBrightnessHUD = defaults.object(forKey: Key.replaceBrightnessHUD) as? Bool ?? false
        hudPlaysSound = defaults.object(forKey: Key.hudSound) as? Bool ?? false
        hidesBatteryPercentage = defaults.object(forKey: Key.hideBatteryPercentage) as? Bool ?? false
        showsDeviceActivity = defaults.object(forKey: Key.deviceActivity) as? Bool ?? true
        showsAudioOutputActivity = defaults.object(forKey: Key.audioOutputActivity) as? Bool ?? true
        showsCalendarActivity = defaults.object(forKey: Key.calendarActivity) as? Bool ?? true
        calendarLeadMinutes = defaults.object(forKey: Key.calendarLeadMinutes) as? Int ?? 10
        showsEventAtRest = defaults.object(forKey: Key.eventAtRest) as? Bool ?? false
        hiddenCalendarIDs = Set(defaults.stringArray(forKey: Key.hiddenCalendars) ?? [])
        opensOnHover = defaults.object(forKey: Key.opensOnHover) as? Bool ?? true
        hoverOpenSeconds = defaults.object(forKey: Key.hoverOpenSeconds) as? Double ?? 3.0
        quickPeek = defaults.object(forKey: Key.quickPeek) as? Bool ?? true
        displayTarget = Self.value(defaults, Key.displayTarget) ?? .followPointer
        simulatedNotch = defaults.object(forKey: Key.simulatedNotch) as? Bool ?? false
        simulatedNotchWidth = defaults.object(forKey: Key.simulatedNotchWidth) as? Double ?? 200
        simulatedNotchHeight = defaults.object(forKey: Key.simulatedNotchHeight) as? Double ?? 32
    }

    /// Put every value back to its default.
    func reset() {
        overlayStyle = Self.defaultOverlayStyle
        material = Self.defaultMaterial
        accent = Self.defaultAccent
        motion = Self.defaultMotion
        contrastOutline = false
        haptics = false
        hideFromScreenCapture = false
        keepAwake = false
        playerTint = Self.defaultPlayerTint
        useLiveWaveform = false
        mediaSource = Self.defaultMediaSource
        hidesMediaWhenSourceFrontmost = false
        swipeGesturesEnabled = true
        naturalSwipeDirection = true
        showsWeather = true
        temperatureUnit = .celsius
        showsChargingActivity = true
        showsLowBatteryActivity = true
        lowBatteryThreshold = 20
        showsLowPowerModeActivity = true
        replacesVolumeHUD = false
        replacesBrightnessHUD = false
        hudPlaysSound = false
        hidesBatteryPercentage = false
        showsDeviceActivity = true
        showsAudioOutputActivity = true
        showsCalendarActivity = true
        calendarLeadMinutes = 10
        showsEventAtRest = false
        hiddenCalendarIDs = []
        opensOnHover = true
        hoverOpenSeconds = 3.0
        quickPeek = true
        displayTarget = .followPointer
        simulatedNotch = false
        simulatedNotchWidth = 200
        simulatedNotchHeight = 32
    }

    private static func value<T: RawRepresentable>(_ defaults: UserDefaults, _ key: String) -> T?
    where T.RawValue == String {
        defaults.string(forKey: key).flatMap(T.init(rawValue:))
    }
}
