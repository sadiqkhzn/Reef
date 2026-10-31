import Foundation

/// A simple stopwatch the island can run alongside the timer.
///
/// It measures elapsed time against the wall clock so it stays accurate across
/// late ticks, and keeps a published `elapsed` the views watch.
@MainActor
final class StopwatchController: ObservableObject {
    /// Seconds counted so far.
    @Published private(set) var elapsed: TimeInterval = 0
    /// True while counting up; false when paused.
    @Published private(set) var isRunning = false

    /// There is something to show: running, or paused with time on the clock.
    var isActive: Bool { isRunning || elapsed > 0 }

    /// Elapsed seconds accumulated before the current run segment began.
    private var base: TimeInterval = 0
    private var startDate: Date?
    private var ticker: Timer?

    /// Start or resume counting.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        startDate = Date()
        beginTicking()
    }

    /// Pause counting, holding the elapsed time.
    func pause() {
        guard isRunning else { return }
        base = elapsed
        isRunning = false
        startDate = nil
        ticker?.invalidate()
        ticker = nil
    }

    /// Stop and clear the clock.
    func reset() {
        ticker?.invalidate()
        ticker = nil
        startDate = nil
        isRunning = false
        base = 0
        elapsed = 0
    }

    private func beginTicking() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        guard isRunning, let startDate else { return }
        elapsed = base + Date().timeIntervalSince(startDate)
    }

    /// A clock label like "0:05.3", or "1:02:05.3" once past an hour. Shows
    /// tenths so a running stopwatch reads as moving.
    static func label(_ seconds: TimeInterval) -> String {
        let total = max(0, seconds)
        let h = Int(total) / 3600
        let m = (Int(total) % 3600) / 60
        let s = Int(total) % 60
        let tenths = Int((total - total.rounded(.down)) * 10)
        if h > 0 {
            return String(format: "%d:%02d:%02d.%d", h, m, s, tenths)
        }
        return String(format: "%d:%02d.%d", m, s, tenths)
    }

    /// A compact label without tenths, for the resting wing: "0:05" or "1:02:05".
    static func shortLabel(_ seconds: TimeInterval) -> String {
        let total = max(0, seconds)
        let h = Int(total) / 3600
        let m = (Int(total) % 3600) / 60
        let s = Int(total) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
