import AppKit
import ApplicationServices
import Combine

/// Works out the discrete steps the volume and brightness keys move through.
///
/// macOS moves these levels in sixteenths, so pressing a key snaps to the
/// nearest sixteenth and then moves one step from there. Pure, so the stepping
/// can be tested without any hardware.
enum HUDStep {
    /// Number of steps from silent/dark to full.
    static let count: Float = 16

    /// The level one step up or down from `current`, snapped to the grid and
    /// clamped to 0...1.
    static func stepped(_ current: Float, up: Bool) -> Float {
        let unit: Float = 1 / count
        let nearest = (current / unit).rounded()
        let moved = nearest + (up ? 1 : -1)
        return min(max(moved * unit, 0), 1)
    }
}

/// Replaces the system's volume and brightness overlays with Reef's.
///
/// It listens for the volume and brightness keys, and for the ones the person
/// has turned on, it swallows the key, changes the level itself, and shows a HUD
/// in the notch. Keys for a part that is turned off, or that it cannot act on
/// (an output with no software volume, an external display with no brightness
/// control), are passed straight through, so the system handles them and shows
/// its own overlay. That fail-open behaviour means a key is never left dead, and
/// turning the feature off or quitting Reef restores the system overlays at
/// once.
///
/// Taking over the keys needs Accessibility permission. Until it is granted the
/// tap cannot be installed, so the system overlays simply keep working.
@MainActor
final class SystemHUDController {
    private let settings: ReefSettings
    private let activities: LiveActivityCenter
    private let monitor = MediaKeyMonitor()
    private var cancellables: Set<AnyCancellable> = []

    /// A short click, played when volume changes if the person asked for it.
    private let feedbackSound = NSSound(named: NSSound.Name("Tink"))

    init(settings: ReefSettings, activities: LiveActivityCenter) {
        self.settings = settings
        self.activities = activities
        monitor.onKeyPress = { [weak self] press in
            self?.handle(press) ?? false
        }
    }

    /// Whether the feature was on at the last check, so a settings change can
    /// tell "the person just turned it on" (worth a one-time prompt) from a
    /// passive re-check (never prompts).
    private var wasWanted = false

    /// Begin watching settings and, if anything is turned on, the keys. Also
    /// re-checks when the app comes forward, so granting Accessibility in System
    /// Settings and switching back starts interception without a restart — and
    /// without prompting again.
    func start() {
        wasWanted = settings.replacesVolumeHUD || settings.replacesBrightnessHUD

        settings.$replacesVolumeHUD
            .combineLatest(settings.$replacesBrightnessHUD)
            .dropFirst()
            .sink { [weak self] volume, brightness in
                guard let self else { return }
                let wanted = volume || brightness
                // Only prompt the moment the person switches the feature on, not
                // on every toggle or re-check.
                let justEnabled = wanted && !self.wasWanted
                self.wasWanted = wanted
                self.refresh(prompting: justEnabled)
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.refresh(prompting: false) }
            .store(in: &cancellables)

        // At launch, start the tap if already trusted; never prompt on launch.
        refresh(prompting: false)
    }

    /// Whether Reef currently has Accessibility permission.
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Ask the system to prompt for Accessibility permission. The prompt only
    /// appears the first time; afterwards it sends the person to System Settings.
    static func requestAccessibility() {
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Open the Accessibility pane of System Settings.
    static func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
    }

    /// Start or stop the key tap to match the current settings. Prompts for
    /// Accessibility only when `prompting` is true (the person just turned the
    /// feature on); otherwise it silently waits until access is granted, so a
    /// passive re-check — opening the menu, switching back to Reef — never raises
    /// the permission dialog again.
    private func refresh(prompting: Bool) {
        let wanted = settings.replacesVolumeHUD || settings.replacesBrightnessHUD
        guard wanted else {
            monitor.stop()
            return
        }
        if Self.isTrusted {
            if !monitor.isRunning {
                monitor.start()
            }
        } else if prompting {
            // Not permitted yet, and the person just asked for it: prompt once and
            // leave the system overlays in charge until access is granted.
            Self.requestAccessibility()
        }
    }

    /// Decide what to do with a key press. Returns true to swallow it.
    private func handle(_ press: MediaKeyPress) -> Bool {
        switch press.key {
        case .volumeUp, .volumeDown:
            return handleVolume(up: press.key == .volumeUp, press: press)
        case .mute:
            return handleMute(press: press)
        case .brightnessUp, .brightnessDown:
            return handleBrightness(up: press.key == .brightnessUp, press: press)
        }
    }

    private func handleVolume(up: Bool, press: MediaKeyPress) -> Bool {
        guard settings.replacesVolumeHUD else { return false }
        // Only act on the press and its repeats; swallow the matching release so
        // the system never sees a half event.
        guard press.isDown else { return true }
        guard let current = SystemVolume.level() else { return false }

        let wasMuted = SystemVolume.isMuted()
        let next = HUDStep.stepped(current, up: up)
        guard SystemVolume.setLevel(next) else { return false }
        // Nudging the volume up while muted unmutes, as the system does.
        if wasMuted && up && next > 0 {
            SystemVolume.setMuted(false)
        }

        let muted = next <= 0 || SystemVolume.isMuted()
        activities.presentHUD(.volume(level: Double(next), muted: muted))
        if settings.hudPlaysSound {
            playFeedback()
        }
        return true
    }

    private func handleMute(press: MediaKeyPress) -> Bool {
        guard settings.replacesVolumeHUD else { return false }
        // Toggle once per press, never on the auto-repeats or the release.
        guard press.isDown, !press.isRepeat else { return true }

        let newMuted = !SystemVolume.isMuted()
        guard SystemVolume.setMuted(newMuted) else { return false }
        let level = SystemVolume.level().map(Double.init) ?? 0
        activities.presentHUD(.volume(level: level, muted: newMuted))
        return true
    }

    private func handleBrightness(up: Bool, press: MediaKeyPress) -> Bool {
        guard settings.replacesBrightnessHUD else { return false }
        guard press.isDown else { return true }
        guard let current = SystemBrightness.level() else { return false }

        let next = HUDStep.stepped(current, up: up)
        guard SystemBrightness.setLevel(next) else { return false }
        activities.presentHUD(.brightness(level: Double(next)))
        return true
    }

    private func playFeedback() {
        guard let feedbackSound else { return }
        feedbackSound.stop()
        feedbackSound.play()
    }
}
