import Foundation
import IOKit

/// Pure rule for whether the Mac counts as idle, split out so it can be tested.
enum IdleDecision {
    static func isIdle(seconds: TimeInterval, threshold: TimeInterval) -> Bool {
        seconds >= threshold
    }
}

/// Reports when the Mac has been idle (no keyboard or pointer input) for longer
/// than a threshold, and when input returns.
///
/// Idle time is read from the HID system, which the window server keeps whether
/// or not Reef is frontmost, so it is dependable across other apps. A one-second
/// poll is enough for an ambient display; input is dismissed promptly by the
/// controller's own event watch, not by this timer.
@MainActor
final class IdleMonitor {
    /// Called with true when idle passes the threshold, and false on the first
    /// poll that sees input again.
    var onIdleChange: ((Bool) -> Void)?

    /// Seconds of inactivity before idle is reported.
    var threshold: TimeInterval = 300

    private var timer: Timer?
    private(set) var isIdle = false

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if isIdle {
            isIdle = false
        }
    }

    /// Seconds since the last HID input event (key, pointer move, click).
    static func idleSeconds() -> TimeInterval {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else { return 0 }
        defer { IOObjectRelease(service) }

        guard let property = IORegistryEntryCreateCFProperty(
            service, "HIDIdleTime" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() else {
            return 0
        }
        // HIDIdleTime is reported in nanoseconds.
        let nanoseconds: UInt64
        if let number = property as? NSNumber {
            nanoseconds = number.uint64Value
        } else {
            return 0
        }
        return TimeInterval(nanoseconds) / 1_000_000_000
    }

    private func tick() {
        let idle = IdleDecision.isIdle(seconds: Self.idleSeconds(), threshold: threshold)
        guard idle != isIdle else { return }
        isIdle = idle
        onIdleChange?(idle)
    }
}
