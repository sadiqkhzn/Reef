import AppKit
import Foundation

/// Plays a short chime at the top of each hour, when the person turns it on.
///
/// A timer is scheduled to fire exactly on the next hour and then every hour
/// after, so the chime lands on the hour rather than drifting.
@MainActor
final class ChimeController: ObservableObject {
    private let settings: ReefSettings
    private var timer: Timer?

    init(settings: ReefSettings) {
        self.settings = settings
    }

    func start() {
        scheduleNextHour()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleNextHour() {
        let next = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)

        let timer = Timer(fire: next, interval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.settings.hourlyChime else { return }
                Self.play()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Play the chime. Also used by the settings preview.
    static func play() {
        NSSound(named: NSSound.Name("Ping"))?.play()
    }
}
