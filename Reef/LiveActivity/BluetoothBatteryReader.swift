import Foundation
import IOKit

/// Reads battery levels for connected Bluetooth devices from the IO registry.
///
/// Apple exposes AirPods and HID device battery on `AppleDeviceManagementHID`
/// `EventService` entries, as whole-percent properties. This reads those public
/// registry keys; it holds no private framework. The interpretation lives in
/// `DeviceBattery`, so this layer only maps registry keys to cells.
enum BluetoothBatteryReader {

    /// Every connected device that reports a battery level.
    static func all() -> [DeviceBattery] {
        guard let matching = IOServiceMatching("AppleDeviceManagementHIDEventService") else {
            return []
        }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var result: [DeviceBattery] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            var unmanaged: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                let properties = unmanaged?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            guard let name = (properties["Product"] as? String) ?? (properties["BatteryName"] as? String),
                !name.isEmpty else {
                continue
            }

            func percent(_ key: String) -> Int? { (properties[key] as? NSNumber)?.intValue }

            var values: [DeviceBattery.Cell: Int] = [:]
            if let v = percent("BatteryPercent") { values[.single] = v }
            if let v = percent("BatteryPercentSingle") { values[.single] = v }
            if let v = percent("BatteryPercentLeft") { values[.left] = v }
            if let v = percent("BatteryPercentRight") { values[.right] = v }
            if let v = percent("BatteryPercentCase") { values[.case] = v }

            let charging = (properties["BatteryStatusFlags"] as? NSNumber)?.intValue ?? 0 != 0

            if let battery = DeviceBattery.make(name: name, values: values, charging: charging) {
                result.append(battery)
            }
        }
        return result
    }

    /// The battery for a device by its advertised name. The registry's `Product`
    /// string may differ slightly from the Bluetooth name, so a loose match is
    /// tried after an exact one.
    static func battery(forDeviceNamed name: String) -> DeviceBattery? {
        let target = name.lowercased()
        let devices = all()
        return devices.first { $0.name.lowercased() == target }
            ?? devices.first {
                $0.name.lowercased().contains(target) || target.contains($0.name.lowercased())
            }
    }
}
