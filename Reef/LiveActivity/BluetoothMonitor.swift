import Foundation
import IOBluetooth

/// Reports Bluetooth devices as they connect and disconnect.
///
/// IOBluetooth calls back once for every device that is already connected the
/// moment the observer registers, so callbacks during a short settle period
/// after starting are ignored. Only connections that happen afterwards reach
/// `onConnect`. A disconnect notification is registered for each device as it
/// connects, so unplugging reaches `onDisconnect`.
@MainActor
final class BluetoothMonitor: NSObject {
    /// Called with the device's name when it connects.
    var onConnect: ((String) -> Void)?
    /// Called with the device's name when it disconnects.
    var onDisconnect: ((String) -> Void)?

    private var registration: IOBluetoothUserNotification?
    /// Per-device disconnect registrations, kept alive until they fire.
    private var disconnectRegistrations: [IOBluetoothUserNotification] = []
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
        disconnectRegistrations.forEach { $0.unregister() }
        disconnectRegistrations.removeAll()
    }

    @objc private func deviceConnected(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        guard Date().timeIntervalSince(startedAt) > settlePeriod else { return }

        // Follow this device for its disconnect, which has no global notifier.
        if let watch = device.register(
            forDisconnectNotification: self,
            selector: #selector(deviceDisconnected(_:device:))) {
            disconnectRegistrations.append(watch)
        }

        onConnect?(name(for: device))
    }

    @objc private func deviceDisconnected(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        notification.unregister()
        disconnectRegistrations.removeAll { $0 === notification }
        onDisconnect?(name(for: device))
    }

    private func name(for device: IOBluetoothDevice) -> String {
        device.name ?? device.nameOrAddress ?? "Bluetooth device"
    }
}
