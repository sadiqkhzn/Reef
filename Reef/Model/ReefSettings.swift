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
        static let focusActivity = "liveActivity.focus"
        static let batteryActivitiesEnabled = "battery.activitiesEnabled"
        static let batteryActivityDuration = "battery.activityDuration"
        static let lowBatterySound = "battery.lowSound"
        static let hideActivityLabel = "liveActivity.hideLabel"
        static let connectivityDuration = "connectivity.duration"
        static let deviceLowBatteryWarning = "connectivity.lowWarning"
        static let deviceLowBatteryThreshold = "connectivity.lowThreshold"
        static let deviceLowBatterySound = "connectivity.lowSound"
        static let deviceArtwork = "connectivity.artwork"
        static let replaceVolumeHUD = "hud.replaceVolume"
        static let replaceBrightnessHUD = "hud.replaceBrightness"
        static let hudSound = "hud.sound"
        static let ambientEnabled = "ambient.enabled"
        static let ambientIdleMinutes = "ambient.idleMinutes"
        static let ambientNowPlaying = "ambient.nowPlaying"
        static let ambientWeather = "ambient.weather"
        static let ambientBattery = "ambient.battery"
        static let ambientNextEvent = "ambient.nextEvent"
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
        static let soundOnLock = "lock.soundOnLock"
        static let soundOnUnlock = "lock.soundOnUnlock"
        static let lockScreenOverlay = "lock.overlay"
        static let lockCardStyle = "lock.cardStyle"
        static let lockShowsIsland = "lock.showsIsland"
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

    /// Show Reef's overlay (clock, media, weather, battery) over the lock shield.
    @Published var lockScreenOverlay: Bool {
        didSet { defaults.set(lockScreenOverlay, forKey: Key.lockScreenOverlay) }
    }

    /// Surface style for the lock-screen Now Playing card.
    @Published var lockCardStyle: LockCardStyle {
        didSet { defaults.set(lockCardStyle.rawValue, forKey: Key.lockCardStyle) }
    }

    /// Also show a compact island pill (now playing) at the top of the lock screen.
    @Published var lockShowsIsland: Bool {
        didSet { defaults.set(lockShowsIsland, forKey: Key.lockShowsIsland) }
    }

    /// Play a sound when the screen locks.
    @Published var soundOnLock: Bool {
        didSet { defaults.set(soundOnLock, forKey: Key.soundOnLock) }
    }

    /// Play a sound when the screen unlocks.
    @Published var soundOnUnlock: Bool {
        didSet { defaults.set(soundOnUnlock, forKey: Key.soundOnUnlock) }
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

    /// Master switch for every battery activity (charging, full, low, low power).
    /// Off hides them all without losing the individual choices below.
    @Published var batteryActivitiesEnabled: Bool {
        didSet { defaults.set(batteryActivitiesEnabled, forKey: Key.batteryActivitiesEnabled) }
    }

    /// How long a battery activity stays in the wings, in seconds.
    @Published var batteryActivityDuration: Double {
        didSet { defaults.set(batteryActivityDuration, forKey: Key.batteryActivityDuration) }
    }

    /// Play a sound when the battery runs low.
    @Published var lowBatterySound: Bool {
        didSet { defaults.set(lowBatterySound, forKey: Key.lowBatterySound) }
    }

    /// Hide the short text label in the middle of the wings (on Macs with no
    /// notch), leaving just the glyph and value.
    @Published var hidesActivityLabel: Bool {
        didSet { defaults.set(hidesActivityLabel, forKey: Key.hideActivityLabel) }
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

    /// Show the wings when a macOS Focus turns on or off.
    @Published var showsFocusActivity: Bool {
        didSet { defaults.set(showsFocusActivity, forKey: Key.focusActivity) }
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

    /// Show the full-screen ambient display when the Mac is idle and unlocked.
    @Published var ambientEnabled: Bool {
        didSet { defaults.set(ambientEnabled, forKey: Key.ambientEnabled) }
    }

    /// Minutes of inactivity before the ambient display appears.
    @Published var ambientIdleMinutes: Int {
        didSet { defaults.set(ambientIdleMinutes, forKey: Key.ambientIdleMinutes) }
    }

    /// Show the playing track on the ambient display.
    @Published var ambientShowsNowPlaying: Bool {
        didSet { defaults.set(ambientShowsNowPlaying, forKey: Key.ambientNowPlaying) }
    }

    /// Show the weather on the ambient display.
    @Published var ambientShowsWeather: Bool {
        didSet { defaults.set(ambientShowsWeather, forKey: Key.ambientWeather) }
    }

    /// Show the battery on the ambient display.
    @Published var ambientShowsBattery: Bool {
        didSet { defaults.set(ambientShowsBattery, forKey: Key.ambientBattery) }
    }

    /// Show the next calendar event on the ambient display.
    @Published var ambientShowsNextEvent: Bool {
        didSet { defaults.set(ambientShowsNextEvent, forKey: Key.ambientNextEvent) }
    }

    /// Hide the battery number on the badge and the home card.
    @Published var hidesBatteryPercentage: Bool {
        didSet { defaults.set(hidesBatteryPercentage, forKey: Key.hideBatteryPercentage) }
    }

    /// Show the wings when headphones or another Bluetooth device connects.
    @Published var showsDeviceActivity: Bool {
        didSet { defaults.set(showsDeviceActivity, forKey: Key.deviceActivity) }
    }

    /// Whether devices are drawn as Reef's 3D models or as SF Symbols.
    @Published var deviceArtwork: DeviceArtwork {
        didSet { defaults.set(deviceArtwork.rawValue, forKey: Key.deviceArtwork) }
    }

    /// How long a connectivity activity stays in the wings, in seconds.
    @Published var connectivityDuration: Double {
        didSet { defaults.set(connectivityDuration, forKey: Key.connectivityDuration) }
    }

    /// Warn when a connected device (AirPods, headphones) runs low.
    @Published var deviceLowBatteryWarning: Bool {
        didSet { defaults.set(deviceLowBatteryWarning, forKey: Key.deviceLowBatteryWarning) }
    }

    /// Percent at which a connected device's low-battery warning shows.
    @Published var deviceLowBatteryThreshold: Int {
        didSet { defaults.set(deviceLowBatteryThreshold, forKey: Key.deviceLowBatteryThreshold) }
    }

    /// Play a sound with a connected device's low-battery warning.
    @Published var deviceLowBatterySound: Bool {
        didSet { defaults.set(deviceLowBatterySound, forKey: Key.deviceLowBatterySound) }
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
        lockScreenOverlay = defaults.object(forKey: Key.lockScreenOverlay) as? Bool ?? false
        lockCardStyle = LockCardStyle(rawValue: defaults.string(forKey: Key.lockCardStyle) ?? "")
            ?? .glass
        lockShowsIsland = defaults.object(forKey: Key.lockShowsIsland) as? Bool ?? false
        soundOnLock = defaults.object(forKey: Key.soundOnLock) as? Bool ?? false
        soundOnUnlock = defaults.object(forKey: Key.soundOnUnlock) as? Bool ?? false
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
        batteryActivitiesEnabled = defaults.object(forKey: Key.batteryActivitiesEnabled) as? Bool ?? true
        batteryActivityDuration = defaults.object(forKey: Key.batteryActivityDuration) as? Double ?? 5
        lowBatterySound = defaults.object(forKey: Key.lowBatterySound) as? Bool ?? false
        hidesActivityLabel = defaults.object(forKey: Key.hideActivityLabel) as? Bool ?? false
        showsChargingActivity = defaults.object(forKey: Key.chargingActivity) as? Bool ?? true
        showsLowBatteryActivity = defaults.object(forKey: Key.lowBatteryActivity) as? Bool ?? true
        lowBatteryThreshold = defaults.object(forKey: Key.lowBatteryThreshold) as? Int ?? 20
        showsLowPowerModeActivity = defaults.object(forKey: Key.lowPowerModeActivity) as? Bool ?? true
        showsFocusActivity = defaults.object(forKey: Key.focusActivity) as? Bool ?? true
        replacesVolumeHUD = defaults.object(forKey: Key.replaceVolumeHUD) as? Bool ?? false
        replacesBrightnessHUD = defaults.object(forKey: Key.replaceBrightnessHUD) as? Bool ?? false
        hudPlaysSound = defaults.object(forKey: Key.hudSound) as? Bool ?? false
        ambientEnabled = defaults.object(forKey: Key.ambientEnabled) as? Bool ?? false
        ambientIdleMinutes = defaults.object(forKey: Key.ambientIdleMinutes) as? Int ?? 5
        ambientShowsNowPlaying = defaults.object(forKey: Key.ambientNowPlaying) as? Bool ?? true
        ambientShowsWeather = defaults.object(forKey: Key.ambientWeather) as? Bool ?? true
        ambientShowsBattery = defaults.object(forKey: Key.ambientBattery) as? Bool ?? true
        ambientShowsNextEvent = defaults.object(forKey: Key.ambientNextEvent) as? Bool ?? true
        hidesBatteryPercentage = defaults.object(forKey: Key.hideBatteryPercentage) as? Bool ?? false
        showsDeviceActivity = defaults.object(forKey: Key.deviceActivity) as? Bool ?? true
        deviceArtwork = Self.value(defaults, Key.deviceArtwork) ?? .models
        connectivityDuration = defaults.object(forKey: Key.connectivityDuration) as? Double ?? 5
        deviceLowBatteryWarning = defaults.object(forKey: Key.deviceLowBatteryWarning) as? Bool ?? true
        deviceLowBatteryThreshold = defaults.object(forKey: Key.deviceLowBatteryThreshold) as? Int ?? 20
        deviceLowBatterySound = defaults.object(forKey: Key.deviceLowBatterySound) as? Bool ?? false
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
        lockScreenOverlay = false
        lockCardStyle = .glass
        lockShowsIsland = false
        soundOnLock = false
        soundOnUnlock = false
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
        batteryActivitiesEnabled = true
        batteryActivityDuration = 5
        lowBatterySound = false
        hidesActivityLabel = false
        showsChargingActivity = true
        showsLowBatteryActivity = true
        lowBatteryThreshold = 20
        showsLowPowerModeActivity = true
        showsFocusActivity = true
        replacesVolumeHUD = false
        replacesBrightnessHUD = false
        hudPlaysSound = false
        ambientEnabled = false
        ambientIdleMinutes = 5
        ambientShowsNowPlaying = true
        ambientShowsWeather = true
        ambientShowsBattery = true
        ambientShowsNextEvent = true
        hidesBatteryPercentage = false
        showsDeviceActivity = true
        deviceArtwork = .models
        connectivityDuration = 5
        deviceLowBatteryWarning = true
        deviceLowBatteryThreshold = 20
        deviceLowBatterySound = false
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
