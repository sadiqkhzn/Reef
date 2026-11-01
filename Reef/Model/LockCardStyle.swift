import Foundation

/// How the Now Playing card on the lock screen is drawn. These mirror the
/// island's own material choices, plus a color-filled option.
enum LockCardStyle: String, CaseIterable, Identifiable {
    /// The card is filled with the vivid color drawn from the album art. The
    /// color stays inside the card — no outside glow.
    case colored
    /// Frosted translucent glass: a blurred, dimmed view of the wallpaper.
    case glass
    /// Minimal and clear: mostly the wallpaper, with just a faint tint and a
    /// crisp outline — like the floating island's clear look.
    case clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .colored: return "Colored"
        case .glass: return "Glass"
        case .clear: return "Clear"
        }
    }
}
