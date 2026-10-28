import Foundation
import IOBluetooth

/// Reports Bluetooth devices as they connect.
///
/// IOBluetooth calls back once for every device that is already connected the
/// moment the observer registers, so callbacks during a short settle period
/// after starting are ignored. Only connections that happen afterwards reach
/// `onConnect`.
@MainActor
final class BluetoothMonitor: NSObject {
    /// Called with the device's name when it connects.
    var onConnect: ((String) -> Void)?

    private var registration: IOBluetoothUserNotification?
    private var startedAt = Date.distantPast
    private let settlePeriod: TimeInterval = 3

    func start() {
        guard registration == nil else { return }
        startedAt = Date()
        registration = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:)))
    }

    func stop() {
        registration?.unregister()
        registration = nil
    }

    @objc private func deviceConnected(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        guard Date().timeIntervalSince(startedAt) > settlePeriod else { return }
        onConnect?(device.name ?? device.nameOrAddress ?? "Bluetooth device")
    }
}
