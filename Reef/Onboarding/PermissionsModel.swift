import AppKit
import CoreBluetooth
import CoreLocation
import EventKit
import Foundation

/// Whether a permission has been granted, refused, or not yet asked for.
enum PermissionStatus {
    case notDetermined
    case granted
    case denied
}

/// Tracks the permissions Reef uses and offers to request or reveal them, for
/// the onboarding screen.
@MainActor
final class PermissionsModel: NSObject, ObservableObject {
    @Published private(set) var calendar: PermissionStatus = .notDetermined
    @Published private(set) var location: PermissionStatus = .notDetermined
    @Published private(set) var bluetooth: PermissionStatus = .notDetermined

    /// The permissions Reef asks for, so the onboarding flow can treat them
    /// uniformly.
    enum Permission { case calendar, location, bluetooth }

    /// The current status of one permission.
    func status(_ permission: Permission) -> PermissionStatus {
        switch permission {
        case .calendar: return calendar
        case .location: return location
        case .bluetooth: return bluetooth
        }
    }

    /// Fire the system prompt for one permission.
    func request(_ permission: Permission) {
        switch permission {
        case .calendar: requestCalendar()
        case .location: requestLocation()
        case .bluetooth: requestBluetooth()
        }
    }

    /// Open the relevant pane in System Settings for one permission.
    func openSettings(_ permission: Permission) {
        switch permission {
        case .calendar: openCalendarSettings()
        case .location: openLocationSettings()
        case .bluetooth: openBluetoothSettings()
        }
    }

    /// Called after the person answers a prompt, so the onboarding window can
    /// bring itself back to the front.
    var onResolved: (() -> Void)?

    private let eventStore = EKEventStore()
    private let locationManager = CLLocationManager()
    /// Created only when the person asks to allow Bluetooth, so it does not
    /// prompt on its own.
    private var central: CBCentralManager?

    override init() {
        super.init()
        locationManager.delegate = self
        refresh()
    }

    func refresh() {
        // EventKit can report notDetermined for a moment right after a grant, so
        // never let a refresh pull an already-granted calendar back to the Allow
        // state; a real revoke comes through as denied, which still updates.
        let newCalendar = Self.calendarStatus()
        if !(newCalendar == .notDetermined && calendar == .granted) {
            calendar = newCalendar
        }
        location = Self.status(for: locationManager.authorizationStatus)
        bluetooth = Self.status(for: CBManager.authorization)
    }

    // MARK: - Calendar

    func requestCalendar() {
        eventStore.requestFullAccessToEvents { [weak self] granted, _ in
            Task { @MainActor in
                guard let self else { return }
                // Trust the result directly; the queried status can lag TCC for
                // a moment right after the prompt.
                self.calendar = granted ? .granted : .denied
                self.onResolved?()
            }
        }
    }

    func openCalendarSettings() {
        Self.open("x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
    }

    private static func calendarStatus() -> PermissionStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    // MARK: - Location

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
    }

    func openLocationSettings() {
        Self.open("x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
    }

    private static func status(for authorization: CLAuthorizationStatus) -> PermissionStatus {
        switch authorization {
        case .authorized, .authorizedAlways: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    // MARK: - Bluetooth

    func requestBluetooth() {
        // Instantiating the manager is what prompts, so it happens here.
        if central == nil {
            central = CBCentralManager(delegate: self, queue: nil)
        }
        // The state delegate fires on power, not on the person's answer, so poll
        // the authorization until it resolves, then surface it and refocus.
        pollBluetooth(remaining: 40)
    }

    private func pollBluetooth(remaining: Int) {
        let status = Self.status(for: CBManager.authorization)
        if status != .notDetermined {
            bluetooth = status
            onResolved?()
            return
        }
        guard remaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.pollBluetooth(remaining: remaining - 1)
        }
    }

    func openBluetoothSettings() {
        Self.open("x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")
    }

    private static func status(for authorization: CBManagerAuthorization) -> PermissionStatus {
        switch authorization {
        case .allowedAlways: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    // MARK: - Helpers

    private static func open(_ string: String) {
        if let url = URL(string: string) {
            NSWorkspace.shared.open(url)
        }
    }
}

extension PermissionsModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.refresh()
            self.onResolved?()
        }
    }
}

extension PermissionsModel: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Fires on power state, before the person answers, so just refresh; the
        // poll in requestBluetooth handles surfacing the answer and refocusing.
        Task { @MainActor in self.refresh() }
    }
}
