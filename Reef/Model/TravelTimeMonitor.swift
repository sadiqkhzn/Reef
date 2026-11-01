import Combine
import CoreLocation
import Foundation
import MapKit

/// Watches the next calendar event that has a location and, when driving there
/// would mean leaving now, raises a "time to leave" activity.
///
/// Best-effort: it needs location permission, an event with a geocodable
/// location, and a routable path. When any of those is missing it simply does
/// nothing. ETA is computed once per event and cached, so routing requests stay
/// minimal.
@MainActor
final class TravelTimeMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    /// Called when it's time to leave: the event and a phrase like "Leave now".
    var onLeaveNow: ((CalendarEvent, String) -> Void)?

    private let settings: ReefSettings
    private let manager = CLLocationManager()
    private var cancellables: Set<AnyCancellable> = []

    private var currentCoord: CLLocationCoordinate2D?
    private var events: [CalendarEvent] = []
    private var timer: Timer?

    /// Computed leave time per event id, and which are being computed or already
    /// alerted, so each event routes once and fires once.
    private var leaveDates: [String: Date] = [:]
    private var computing: Set<String> = []
    private var alerted: Set<String> = []

    /// Only consider events starting within this window.
    private let horizon: TimeInterval = 3 * 3600

    init(settings: ReefSettings, calendar: CalendarMonitor) {
        self.settings = settings
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced

        calendar.$events
            .sink { [weak self] in self?.events = $0 }
            .store(in: &cancellables)
    }

    func start() {
        manager.requestLocation()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Tick

    private func tick() {
        guard settings.notifyTimeToLeave else { return }
        let now = Date()
        alerted = alerted.intersection(events.map(\.id))

        guard let event = nextLocatedEvent(now: now), !alerted.contains(event.id) else { return }

        if let leaveDate = leaveDates[event.id] {
            if now >= leaveDate && now < event.start {
                alerted.insert(event.id)
                onLeaveNow?(event, leaveText(from: now, to: event.start, leaveDate: leaveDate))
            }
        } else if !computing.contains(event.id) {
            computeLeaveDate(for: event)
        }
    }

    /// The soonest event with a location that starts within the horizon.
    private func nextLocatedEvent(now: Date) -> CalendarEvent? {
        events
            .filter { ($0.location?.isEmpty == false) && $0.start > now
                && $0.start < now.addingTimeInterval(horizon) }
            .min { $0.start < $1.start }
    }

    private func leaveText(from now: Date, to start: Date, leaveDate: Date) -> String {
        let mins = Int((leaveDate.timeIntervalSince(now) / 60).rounded())
        return mins <= 0 ? "Leave now" : "Leave in \(mins) min"
    }

    // MARK: - Routing

    private func computeLeaveDate(for event: CalendarEvent) {
        guard let location = event.location, let origin = currentCoord else {
            manager.requestLocation()
            return
        }
        computing.insert(event.id)

        CLGeocoder().geocodeAddressString(location) { [weak self] placemarks, _ in
            Task { @MainActor in
                guard let self else { return }
                guard let dest = placemarks?.first?.location?.coordinate else {
                    self.computing.remove(event.id); return
                }
                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
                request.transportType = .automobile

                MKDirections(request: request).calculateETA { [weak self] response, _ in
                    Task { @MainActor in
                        guard let self else { return }
                        defer { self.computing.remove(event.id) }
                        guard let eta = response?.expectedTravelTime else { return }
                        let buffer = TimeInterval(self.settings.travelBufferMinutes * 60)
                        self.leaveDates[event.id] = event.start.addingTimeInterval(-eta - buffer)
                    }
                }
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        guard let coord = locations.last?.coordinate else { return }
        Task { @MainActor in self.currentCoord = coord }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
