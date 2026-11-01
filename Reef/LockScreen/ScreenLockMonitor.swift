import AppKit

/// Plays a sound when the screen locks or unlocks.
///
/// macOS posts distributed notifications when the session locks and unlocks,
/// which any app can observe without special permission. This watches those and,
/// for the ones the person turned on, plays a short sound. It never draws on the
/// lock screen (that needs a privileged plugin); it only reacts to the events.
@MainActor
final class ScreenLockMonitor {
    private let settings: ReefSettings
    private var observers: [NSObjectProtocol] = []

    /// Short, distinct sounds for the two events.
    private let lockSound = NSSound(named: NSSound.Name("Tink"))
    private let unlockSound = NSSound(named: NSSound.Name("Pop"))

    init(settings: ReefSettings) {
        self.settings = settings
    }

    func start() {
        let center = DistributedNotificationCenter.default()
        observers.append(
            center.addObserver(
                forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.handleLock() }
            })
        observers.append(
            center.addObserver(
                forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.handleUnlock() }
            })
    }

    func stop() {
        let center = DistributedNotificationCenter.default()
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func handleLock() {
        guard settings.soundOnLock else { return }
        Self.play(lockSound)
    }

    private func handleUnlock() {
        guard settings.soundOnUnlock else { return }
        Self.play(unlockSound)
    }

    /// Preview the lock sound from settings.
    static func previewLock() { play(NSSound(named: NSSound.Name("Tink"))) }
    /// Preview the unlock sound from settings.
    static func previewUnlock() { play(NSSound(named: NSSound.Name("Pop"))) }

    private static func play(_ sound: NSSound?) {
        guard let sound else { return }
        sound.stop()
        sound.play()
    }
}
