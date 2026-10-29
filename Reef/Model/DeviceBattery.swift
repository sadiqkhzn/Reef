import Foundation

/// Battery levels for one connected Bluetooth device.
///
/// Earbuds report a level per side and often one for the case; simpler devices
/// such as a keyboard report a single level. Every value is a whole percent, or
/// nil when the device does not report that cell.
struct DeviceBattery: Equatable {
    var name: String
    var kind: DeviceKind
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    var single: Int?
    /// True when at least one cell is charging.
    var isCharging: Bool = false

    /// The one figure worth showing at a glance. For earbuds it is the lower of
    /// the two sides (the side that will die first); otherwise the single cell,
    /// falling back to whichever side is reported.
    var overall: Int? {
        let sides = [left, right].compactMap { $0 }
        if !sides.isEmpty { return sides.min() }
        return single ?? caseLevel
    }

    /// True when the device reported any battery figure at all.
    var hasReading: Bool {
        left != nil || right != nil || caseLevel != nil || single != nil
    }

    /// A readable line for the open island, naming each reported cell, e.g.
    /// "L 80%  R 85%  Case 90%" or "72%".
    var summary: String {
        var parts: [String] = []
        if let single { parts.append("\(single)%") }
        if let left { parts.append("L \(left)%") }
        if let right { parts.append("R \(right)%") }
        if let caseLevel { parts.append("Case \(caseLevel)%") }
        return parts.joined(separator: "  ")
    }

    /// Build from the raw keys an IORegistry entry exposes, keeping the IOKit
    /// layer free of any interpretation so this can be tested on its own.
    ///
    /// `values` holds whichever of `single`, `left`, `right`, `case` the device
    /// reported, each 0...100. A value of 0 is treated as "not reported", since
    /// absent cells read back as zero on several devices. Returns nil when the
    /// device reports nothing usable.
    static func make(
        name: String,
        values: [Cell: Int],
        charging: Bool = false
    ) -> DeviceBattery? {
        func level(_ cell: Cell) -> Int? {
            guard let raw = values[cell], raw > 0 else { return nil }
            return min(100, raw)
        }

        let battery = DeviceBattery(
            name: name,
            kind: DeviceKind(name: name),
            left: level(.left),
            right: level(.right),
            caseLevel: level(.case),
            single: level(.single),
            isCharging: charging)

        return battery.hasReading ? battery : nil
    }

    /// The battery cells a device may report.
    enum Cell: Hashable {
        case single
        case left
        case right
        case `case`
    }
}
