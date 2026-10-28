import Combine
import Foundation
import IOKit.ps

/// Keeps a current `BatterySnapshot` and refreshes it when the power state
/// changes.
///
/// It listens for the system's power source notifications so plugging in or
/// unplugging shows up right away, and also refreshes on a slow timer so the
/// percentage stays current while discharging.
@MainActor
final class BatteryModel: ObservableObject {
    @Published private(set) var snapshot: BatterySnapshot

    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?

    init() {
        snapshot = BatteryReader.current()
        startListening()
        startTimer()
    }

    deinit {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
        timer?.invalidate()
    }

    func refresh() {
        let next = BatteryReader.current()
        if next != snapshot {
            snapshot = next
        }
    }

    private func startListening() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { raw in
            guard let raw else { return }
            let model = Unmanaged<BatteryModel>.fromOpaque(raw).takeUnretainedValue()
            MainActor.assumeIsolated {
                model.refresh()
            }
        }

        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?
            .takeRetainedValue() else {
            return
        }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func startTimer() {
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
