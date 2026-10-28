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

    init(state: NotchState, settings: ReefSettings, battery: BatteryModel) {
        self.state = state
        self.settings = settings
        self.lastBattery = battery.snapshot

        battery.$snapshot
            .dropFirst()
            .sink { [weak self] next in
                self?.batteryChanged(to: next)
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

    /// A Bluetooth device connected.
    func deviceConnected(named name: String) {
        guard settings.showsDeviceActivity else { return }
        present(.deviceConnected(name: name, kind: DeviceKind(name: name)))
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
        case .deviceConnected: return settings.showsDeviceActivity
        }
    }
}
