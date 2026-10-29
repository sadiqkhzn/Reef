import Foundation

/// Which player the island should follow.
enum MediaSource: String, CaseIterable, Identifiable {
    /// Whatever the system reports as now playing, from any app.
    case automatic
    /// Only Apple Music.
    case appleMusic
    /// Only Spotify.
    case spotify

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        }
    }

    /// Whether a track from this bundle id is allowed through. Automatic lets
    /// everything through; the others match a single app.
    func allows(bundleIdentifier: String?) -> Bool {
        switch self {
        case .automatic: return true
        case .appleMusic: return bundleIdentifier == "com.apple.Music"
        case .spotify: return bundleIdentifier == "com.spotify.client"
        }
    }
}

/// Decides whether the island should show a track right now, given the chosen
/// source and whether the source app is frontmost. Pure, so the rules are
/// tested without a running player or workspace.
enum MediaGate {
    static func shownTrack(
        _ track: NowPlaying?,
        source: MediaSource,
        hideWhenSourceFrontmost: Bool,
        frontmostBundleIdentifier: String?
    ) -> NowPlaying? {
        guard let track else { return nil }
        guard source.allows(bundleIdentifier: track.bundleIdentifier) else { return nil }

        if hideWhenSourceFrontmost,
            let id = track.bundleIdentifier,
            id == frontmostBundleIdentifier {
            return nil
        }
        return track
    }
}
