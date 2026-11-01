import AppKit
import Combine
import Foundation

/// Turns changes in system state into live activities on the island.
///
/// It watches the sources Reef knows about, asks the matching policy whether
/// the change deserves an activity, checks the person's settings, and then
/// shows the activity in the wings for its duration.
@MainActor
final class LiveActivityCenter: ObservableObject {
    private let state: NotchState
    private let settings: ReefSettings
    private var lastBattery: BatterySnapshot
    /// Last known Focus, so turning one off can still name it.
    private var lastFocus: FocusStatus?
    private var dismissWork: DispatchWorkItem?
    private var peekWork: DispatchWorkItem?
    private var cancellables: Set<AnyCancellable> = []
    /// Event ids already shown as a heads-up, so each fires at most once.
    private var alertedEvents: Set<String> = []
    /// Devices already warned about low battery, so each warns once until it
    /// recovers above the threshold.
    private var warnedDevices: Set<String> = []
    private var deviceBatteryTimer: Timer?

    init(
        state: NotchState, settings: ReefSettings, battery: BatteryModel,
        calendar: CalendarMonitor, focus: FocusMonitor
    ) {
        self.state = state
        self.settings = settings
        self.lastBattery = battery.snapshot
        self.lastFocus = focus.current

        battery.$snapshot
            .dropFirst()
            .sink { [weak self] next in
                self?.batteryChanged(to: next)
            }
            .store(in: &cancellables)

        calendar.$events
            .sink { [weak self] events in
                self?.calendarChanged(events)
            }
            .store(in: &cancellables)

        focus.$current
            .dropFirst()
            .sink { [weak self] next in
                self?.focusChanged(to: next)
            }
            .store(in: &cancellables)

        lastLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        NotificationCenter.default
            .publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in self?.powerStateChanged() }
            .store(in: &cancellables)

        // Poll connected-device batteries so a low AirPods/headphone level can
        // raise a one-time warning.
        let timer = Timer(timeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkDeviceBatteries() }
        }
        RunLoop.main.add(timer, forMode: .common)
        deviceBatteryTimer = timer
    }

    /// Warn once when a connected device drops to or below the threshold, and
    /// re-arm the warning once it recovers a few points above it.
    private func checkDeviceBatteries() {
        guard settings.showsDeviceActivity, settings.deviceLowBatteryWarning else { return }
        let threshold = settings.deviceLowBatteryThreshold

        var stillLow: Set<String> = []
        for device in BluetoothBatteryReader.all() {
            guard let percent = device.overall, !device.isCharging else { continue }
            if percent <= threshold {
                stillLow.insert(device.name)
                if !warnedDevices.contains(device.name) {
                    warnedDevices.insert(device.name)
                    present(.deviceLowBattery(
                        name: device.name, kind: DeviceKind(name: device.name), percent: percent))
                }
            }
        }
        // Keep only devices still low; ones that recovered or disconnected are
        // forgotten, so they can warn again next time they run down.
        warnedDevices.formIntersection(stillLow)
    }

    private var lastLowPowerMode = false

    /// Announce Low Power Mode when it turns on.
    private func powerStateChanged() {
        let now = ProcessInfo.processInfo.isLowPowerModeEnabled
        defer { lastLowPowerMode = now }
        guard now, !lastLowPowerMode,
            settings.batteryActivitiesEnabled, settings.showsLowPowerModeActivity else { return }
        present(.lowPowerMode)
    }

    /// Show `activity` in the wings unless a more important one is already
    /// showing. Replaces any lower or equal priority activity.
    func present(_ activity: LiveActivity) {
        if let current = state.liveActivity, current.priority > activity.priority {
            return
        }

        dismissWork?.cancel()
        peekWork?.cancel()
        state.liveActivity = activity
        state.isPeeking = true

        // Battery and connectivity activities honor the person's chosen duration;
        // others keep their built-in timing.
        let duration: TimeInterval
        if activity.isBattery {
            duration = max(1, settings.batteryActivityDuration)
        } else if activity.isConnectivity {
            duration = max(1, settings.connectivityDuration)
        } else {
            duration = activity.duration
        }

        // Low-battery alerts can play a sound, when asked.
        if case .lowBattery = activity, settings.lowBatterySound {
            Self.playLowBatterySound()
        }
        if case .deviceLowBattery = activity, settings.deviceLowBatterySound {
            Self.playLowBatterySound()
        }

        let peek = DispatchWorkItem { [weak self] in
            self?.state.isPeeking = false
        }
        peekWork = peek
        let peekTime = min(LiveActivity.peekDuration, duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + peekTime, execute: peek)

        let work = DispatchWorkItem { [weak self] in
            self?.state.isPeeking = false
            self?.state.liveActivity = nil
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    /// Play the low-battery alert sound. Also used by the settings preview.
    static func playLowBatterySound() {
        NSSound(named: NSSound.Name("Submarine"))?.play()
    }

    /// Show a volume or brightness HUD and hold it briefly, re-arming the
    /// dismiss each time a new level arrives so it stays up while the key is
    /// held. Unlike `present`, it shows no peek detail line and always takes
    /// over, since it answers a direct key press.
    func presentHUD(_ activity: LiveActivity) {
        dismissWork?.cancel()
        peekWork?.cancel()
        state.isPeeking = false
        state.liveActivity = activity

        let work = DispatchWorkItem { [weak self] in
            self?.state.liveActivity = nil
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + activity.duration, execute: work)
    }

    /// A Bluetooth device connected. The battery often lands a moment after the
    /// connection, so if none is reported yet the activity still shows, then
    /// updates in place once a level arrives.
    func deviceConnected(named name: String) {
        guard settings.showsDeviceActivity else { return }
        let kind = DeviceKind(name: name)
        present(.deviceConnected(name: name, kind: kind, battery: readBattery(name)))

        if readBattery(name) == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self,
                    case .deviceConnected(let shown, _, nil)? = self.state.liveActivity,
                    shown == name,
                    let battery = self.readBattery(name) else {
                    return
                }
                self.state.liveActivity = .deviceConnected(name: name, kind: kind, battery: battery)
            }
        }
    }

    /// A Bluetooth device disconnected.
    func deviceDisconnected(named name: String) {
        guard settings.showsDeviceActivity else { return }
        present(.deviceDisconnected(name: name, kind: DeviceKind(name: name)))
    }

    /// System audio switched to a different output.
    func audioOutputChanged(_ output: AudioOutput) {
        guard settings.showsAudioOutputActivity else { return }
        present(.audioOutput(name: output.name, kind: output.kind))
    }

    private func readBattery(_ name: String) -> Int? {
        BluetoothBatteryReader.battery(forDeviceNamed: name)?.overall
    }

    /// When the next event moves inside the lead window, raise a one-time
    /// heads-up for it. Each event's id is remembered so it fires once; ids that
    /// have passed are forgotten so the set does not grow without bound.
    private func calendarChanged(_ events: [CalendarEvent]) {
        guard settings.showsCalendarActivity else { return }
        let now = Date()
        let leadTime = TimeInterval(settings.calendarLeadMinutes * 60)

        let liveIds = Set(events.map(\.id))
        alertedEvents.formIntersection(liveIds)

        guard let next = EventSchedule.next(events, now: now),
            next.isWithinLead(now: now, leadTime: leadTime),
            !alertedEvents.contains(next.id) else {
            return
        }

        alertedEvents.insert(next.id)
        present(.calendarEvent(title: next.title, countdown: next.countdownText(now: now)))
    }

    private func batteryChanged(to next: BatterySnapshot) {
        defer { lastBattery = next }
        guard let activity = BatteryActivityPolicy.activity(
                from: lastBattery, to: next, lowThreshold: settings.lowBatteryThreshold),
              isEnabled(activity) else {
            return
        }
        present(activity)
    }

    /// A Focus turned on, off, or switched to another — show it in the wings.
    private func focusChanged(to next: FocusStatus?) {
        defer { lastFocus = next }
        guard settings.showsFocusActivity else { return }

        if let next {
            // Turned on or switched.
            present(.focus(name: next.name, symbol: next.symbol, on: true))
        } else if let previous = lastFocus {
            // Turned off; name the one that just ended.
            present(.focus(name: previous.name, symbol: previous.symbol, on: false))
        }
    }

    private func isEnabled(_ activity: LiveActivity) -> Bool {
        // The battery master switch gates every battery activity.
        if activity.isBattery && !settings.batteryActivitiesEnabled { return false }
        switch activity {
        case .charging, .fullyCharged: return settings.showsChargingActivity
        case .lowBattery: return settings.showsLowBatteryActivity
        case .deviceConnected, .deviceDisconnected: return settings.showsDeviceActivity
        case .deviceLowBattery:
            return settings.showsDeviceActivity && settings.deviceLowBatteryWarning
        case .audioOutput: return settings.showsAudioOutputActivity
        case .calendarEvent: return settings.showsCalendarActivity
        case .lowPowerMode: return settings.showsLowPowerModeActivity
        case .focus: return settings.showsFocusActivity
        // HUDs are gated by the key handler, not the battery/activity path, and
        // are shown directly through `presentHUD`.
        case .volume, .brightness: return true
        }
    }
}
