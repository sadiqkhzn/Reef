import CoreLocation

/// A thin wrapper over CoreLocation that hands back a coarse coordinate.
///
/// Reduced accuracy is enough for weather, so it never asks for a precise fix.
/// Authorization and the one fix are reported through the two closures.
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    /// Called on the main thread with a coordinate when a fix arrives.
    var onUpdate: ((CLLocationCoordinate2D) -> Void)?
    /// Called when access is refused, so the caller can stop waiting.
    var onDenied: (() -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    /// Ask for access if needed, then request a single fix.
    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorized, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            onDenied?()
        @unknown default:
            break
        }
    }

    /// Request another single fix, when already authorized.
    func requestOnce() {
        let status = manager.authorizationStatus
        if status == .authorized || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorized, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            onDenied?()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        onUpdate?(coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A transient failure just means no fix this time; the next request may
        // succeed, so there is nothing to surface.
    }
}
