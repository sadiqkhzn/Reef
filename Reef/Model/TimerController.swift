import AppKit
import Foundation

/// A single countdown timer the island can run.
///
/// It counts down against the wall clock, so it stays accurate even if a tick is
/// late, and keeps a little published state the views watch: the time left, the
/// total it started from, and whether it is running, paused, or just finished.
@MainActor
final class TimerController: ObservableObject {
    /// Seconds left on the clock. Zero once it finishes.
    @Published private(set) var remaining: TimeInterval = 0
    /// The duration the current timer was started with, for the ring's fraction.
    @Published private(set) var total: TimeInterval = 0
    /// True while counting down; false when paused or finished.
    @Published private(set) var isRunning = false
    /// True for a short while after the timer reaches zero.
    @Published private(set) var isFinished = false

    /// There is a timer to show: running, paused, or finished and not yet cleared.
    var isActive: Bool { total > 0 }

    /// How far through the timer we are, from 0 at the start to 1 at the end.
    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / total))
    }

    private var endDate: Date?
    private var ticker: Timer?
    private var clearWork: DispatchWorkItem?

    /// How long the finished state lingers before it clears itself.
    private let finishedLinger: TimeInterval = 12

    /// Start a fresh countdown of `duration` seconds, replacing any current one.
    func start(_ duration: TimeInterval) {
        guard duration > 0 else { return }
        clearWork?.cancel()
        total = duration
        remaining = duration
        isFinished = false
        isRunning = true
        endDate = Date().addingTimeInterval(duration)
        beginTicking()
    }

    /// Pause a running countdown, holding the time left.
    func pause() {
        guard isRunning else { return }
        isRunning = false
        endDate = nil
        ticker?.invalidate()
        ticker = nil
    }

    /// Resume a paused countdown from where it stopped.
    func resume() {
        guard !isRunning, !isFinished, remaining > 0 else { return }
        isRunning = true
        endDate = Date().addingTimeInterval(remaining)
        beginTicking()
    }

    /// Add a minute to the clock, whether running, paused, or finished.
    func addMinute() {
        clearWork?.cancel()
        if isFinished {
            // Revive a just-finished timer with one more minute.
            isFinished = false
            total = 60
            remaining = 60
            isRunning = true
            endDate = Date().addingTimeInterval(60)
            beginTicking()
            return
        }
        total += 60
        remaining += 60
        if isRunning { endDate = Date().addingTimeInterval(remaining) }
    }

    /// Clear the timer entirely and fold its wing away.
    func cancel() {
        clearWork?.cancel()
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        isRunning = false
        isFinished = false
        total = 0
        remaining = 0
    }

    private func beginTicking() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        guard isRunning, let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            finish()
        } else {
            remaining = left
        }
    }

    private func finish() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        isRunning = false
        isFinished = true
        remaining = 0
        NSSound(named: "Glass")?.play()

        let work = DispatchWorkItem { [weak self] in self?.cancel() }
        clearWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + finishedLinger, execute: work)
    }

    /// A clock label like "25:00", or "1:05:00" once past an hour.
    static func label(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
