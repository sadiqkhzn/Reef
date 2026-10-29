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
    private var dismissWork: DispatchWorkItem?
    private var peekWork: DispatchWorkItem?
    private var cancellables: Set<AnyCancellable> = []
    /// Event ids already shown as a heads-up, so each fires at most once.
    private var alertedEvents: Set<String> = []

    init(state: NotchState, settings: ReefSettings, battery: BatteryModel, calendar: CalendarMonitor) {
        self.state = state
        self.settings = settings
        self.lastBattery = battery.snapshot

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

        let peek = DispatchWorkItem { [weak self] in
            self?.state.isPeeking = false
        }
        peekWork = peek
        let peekTime = min(LiveActivity.peekDuration, activity.duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + peekTime, execute: peek)

        let work = DispatchWorkItem { [weak self] in
            self?.state.isPeeking = false
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
        guard let activity = BatteryActivityPolicy.activity(from: lastBattery, to: next),
              isEnabled(activity) else {
            return
        }
        present(activity)
    }

    private func isEnabled(_ activity: LiveActivity) -> Bool {
        switch activity {
        case .charging, .fullyCharged: return settings.showsChargingActivity
        case .lowBattery: return settings.showsLowBatteryActivity
        case .deviceConnected, .deviceDisconnected: return settings.showsDeviceActivity
        case .audioOutput: return settings.showsAudioOutputActivity
        case .calendarEvent: return settings.showsCalendarActivity
        }
    }
}
