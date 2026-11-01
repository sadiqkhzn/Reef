import Foundation

/// Shared state for the lock-screen overlay, so the view can react to the lock
/// opening before the overlay is torn down.
@MainActor
final class LockScreenState: ObservableObject {
    enum Phase {
        case locked
        /// The password was accepted; play the unlock animation, then the
        /// overlay is removed and the desktop appears.
        case unlocking
    }

    @Published var phase: Phase = .locked
}
