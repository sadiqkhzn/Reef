import Foundation
import IOKit.ps

/// Reads the current battery state from the system power sources.
///
/// The parsing lives in `BatterySnapshot.parse`, which is tested on its own.
/// This type only pulls the dictionary out of IOKit and hands it over.
enum BatteryReader {
    static func current() -> BatterySnapshot {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return .absent
        }
        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue()
            as? [CFTypeRef] else {
            return .absent
        }

        for source in sources {
            if let description = IOPSGetPowerSourceDescription(blob, source)?
                .takeUnretainedValue() as? [String: Any] {
                let snapshot = BatterySnapshot.parse(description)
                if snapshot.isPresent {
                    return snapshot
                }
            }
        }

        return .absent
    }
}
