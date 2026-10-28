import AppKit

/// A snapshot of what the system is currently playing, from any app.
struct NowPlaying: Equatable {
    var title: String
    var artist: String
    var album: String
    var isPlaying: Bool

    /// Bundle id of the app that is playing, when known.
    var bundleIdentifier: String?
    /// Human app name, resolved from the bundle id by the controller.
    var appName: String?

    /// Cover art, decoded once by the controller so the view never decodes it
    /// during a render.
    var artwork: NSImage?
    /// A cheap identity for the artwork so equality does not compare image
    /// bytes. Derived from the encoded source.
    var artworkToken: Int?

    /// Equality ignores the decoded image itself and uses the token instead, so
    /// comparing two snapshots never walks the image data.
    static func == (lhs: NowPlaying, rhs: NowPlaying) -> Bool {
        lhs.title == rhs.title
            && lhs.artist == rhs.artist
            && lhs.album == rhs.album
            && lhs.isPlaying == rhs.isPlaying
            && lhs.bundleIdentifier == rhs.bundleIdentifier
            && lhs.appName == rhs.appName
            && lhs.artworkToken == rhs.artworkToken
    }
}

/// Pure helpers for turning the adapter's JSON stream into a `NowPlaying`.
///
/// The stream sends `{ type, diff, payload }` lines. A non-diff payload is the
/// full state; a diff payload carries only changed keys, where a null value
/// means the key went away. These functions keep that merge logic free of the
/// subprocess so it can be tested directly.
enum NowPlayingStream {

    /// Merge a payload into the running state. A non-diff payload replaces it
    /// entirely; a diff payload updates the given keys and drops any whose value
    /// is null.
    static func merge(_ current: [String: Any], payload: [String: Any], diff: Bool) -> [String: Any] {
        guard diff else { return payload }

        var next = current
        for (key, value) in payload {
            if value is NSNull {
                next.removeValue(forKey: key)
            } else {
                next[key] = value
            }
        }
        return next
    }

    /// Build a `NowPlaying` from merged state, or nil when there is nothing
    /// worth showing. A title is mandatory; everything else is optional.
    ///
    /// Artwork is deliberately left out here: decoding it is expensive and it is
    /// handled separately so it is only decoded when it actually changes.
    static func nowPlaying(from state: [String: Any]) -> NowPlaying? {
        guard let title = state["title"] as? String,
            !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }

        return NowPlaying(
            title: title,
            artist: (state["artist"] as? String) ?? "",
            album: (state["album"] as? String) ?? "",
            isPlaying: (state["playing"] as? Bool) ?? false,
            bundleIdentifier: state["bundleIdentifier"] as? String,
            appName: nil,
            artwork: nil,
            artworkToken: nil)
    }

    /// The base64 artwork string in the state, if any.
    static func encodedArtwork(from state: [String: Any]) -> String? {
        state["artworkData"] as? String
    }
}
