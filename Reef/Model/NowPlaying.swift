import AppKit
import SwiftUI

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
    /// A vivid color drawn from the cover, computed by the controller when the
    /// artwork arrives. Tracks `artworkToken`, so it is left out of equality.
    var tint: Color?

    /// Track length in seconds, when the source reports it.
    var duration: TimeInterval?
    /// Playback position in seconds at the moment the source last reported it.
    /// Pair this with `positionTimestamp` to work out the live position.
    var elapsed: TimeInterval?
    /// When `elapsed` was sampled (seconds since the reference date). Used to
    /// advance the position on screen without the source sending every tick.
    var positionTimestamp: TimeInterval?
    /// Rate playback runs at: 1 while playing, 0 while paused. Lets the view
    /// freeze the position when the source pauses between updates.
    var playbackRate: Double?

    /// True when the queue is shuffled.
    var shuffleOn: Bool = false
    /// Repeat setting: off, this track, or the whole queue.
    var repeatMode: RepeatMode = .off

    /// How the current queue repeats.
    enum RepeatMode: Int {
        case off
        case one
        case all
    }

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
            && lhs.duration == rhs.duration
            && lhs.elapsed == rhs.elapsed
            && lhs.positionTimestamp == rhs.positionTimestamp
            && lhs.playbackRate == rhs.playbackRate
            && lhs.shuffleOn == rhs.shuffleOn
            && lhs.repeatMode == rhs.repeatMode
    }

    /// The position to show right now, advancing `elapsed` by the time passed
    /// since it was sampled when playing. Clamped to the track length.
    func position(at now: TimeInterval) -> TimeInterval? {
        guard let elapsed else { return nil }
        let rate = playbackRate ?? (isPlaying ? 1 : 0)
        let base: TimeInterval
        if let positionTimestamp, rate != 0 {
            base = elapsed + (now - positionTimestamp) * rate
        } else {
            base = elapsed
        }
        guard let duration, duration > 0 else { return max(0, base) }
        return min(max(0, base), duration)
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

        func seconds(_ key: String) -> TimeInterval? {
            guard let micros = (state[key] as? NSNumber)?.doubleValue else { return nil }
            return micros / 1_000_000
        }

        var track = NowPlaying(
            title: title,
            artist: (state["artist"] as? String) ?? "",
            album: (state["album"] as? String) ?? "",
            isPlaying: (state["playing"] as? Bool) ?? false,
            bundleIdentifier: state["bundleIdentifier"] as? String,
            appName: nil,
            artwork: nil,
            artworkToken: nil)

        track.duration = seconds("durationMicros")
        track.elapsed = seconds("elapsedTimeMicros")
        track.positionTimestamp = seconds("timestampEpochMicros")
        track.playbackRate = (state["playbackRate"] as? NSNumber)?.doubleValue

        // The adapter reports shuffle as 1 off / 2 albums / 3 tracks, and repeat
        // as 1 off / 2 this track / 3 the whole queue.
        if let shuffle = (state["shuffleMode"] as? NSNumber)?.intValue {
            track.shuffleOn = shuffle >= 2
        }
        switch (state["repeatMode"] as? NSNumber)?.intValue {
        case 2: track.repeatMode = .one
        case 3: track.repeatMode = .all
        default: track.repeatMode = .off
        }

        return track
    }

    /// The base64 artwork string in the state, if any.
    static func encodedArtwork(from state: [String: Any]) -> String? {
        state["artworkData"] as? String
    }
}
