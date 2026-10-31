import Foundation
import IOKit.pwr_mgt

/// Holds a power assertion that keeps the Mac and its display from sleeping
/// while the person wants it awake. Releasing the assertion lets normal sleep
/// resume.
final class KeepAwakeManager {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        if active {
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Reef keeps the display awake" as CFString,
                &id)
            if result == kIOReturnSuccess {
                assertionID = id
                isActive = true
            }
        } else {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
            isActive = false
        }
    }

    deinit {
        if isActive { IOPMAssertionRelease(assertionID) }
    }
}
