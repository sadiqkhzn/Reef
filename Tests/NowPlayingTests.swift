import XCTest
@testable import Reef

/// Covers the pure stream logic: merging diff payloads and turning merged state
/// into a `NowPlaying`.
final class NowPlayingTests: XCTestCase {

    // MARK: - Mapping state to NowPlaying

    func testBuildsFromFullState() {
        let state: [String: Any] = [
            "title": "Sicko Mode",
            "artist": "Travis Scott",
            "album": "Astroworld",
            "playing": true,
            "bundleIdentifier": "com.apple.Music",
        ]
        let track = NowPlayingStream.nowPlaying(from: state)

        XCTAssertEqual(track?.title, "Sicko Mode")
        XCTAssertEqual(track?.artist, "Travis Scott")
        XCTAssertEqual(track?.album, "Astroworld")
        XCTAssertEqual(track?.isPlaying, true)
        XCTAssertEqual(track?.bundleIdentifier, "com.apple.Music")
    }

    func testNoTitleMeansNothingPlaying() {
        XCTAssertNil(NowPlayingStream.nowPlaying(from: [:]))
        XCTAssertNil(NowPlayingStream.nowPlaying(from: ["playing": true, "artist": "x"]))
        XCTAssertNil(NowPlayingStream.nowPlaying(from: ["title": "   "]))
    }

    func testMissingOptionalFieldsDefault() {
        let track = NowPlayingStream.nowPlaying(from: ["title": "Solo", "playing": false])
        XCTAssertEqual(track?.artist, "")
        XCTAssertEqual(track?.album, "")
        XCTAssertEqual(track?.isPlaying, false)
        XCTAssertNil(track?.bundleIdentifier)
    }

    func testArtworkIsLeftOutOfMappingButReadableSeparately() {
        let bytes = Data([0x1, 0x2, 0x3, 0x4])
        let state: [String: Any] = [
            "title": "Art",
            "artworkData": bytes.base64EncodedString(),
        ]

        // The mapper does not decode artwork (that is cached by the controller).
        XCTAssertNil(NowPlayingStream.nowPlaying(from: state)?.artwork)

        // The encoded string is still readable, and decodes to the bytes.
        let encoded = NowPlayingStream.encodedArtwork(from: state)
        XCTAssertEqual(encoded.flatMap { Data(base64Encoded: $0) }, bytes)
    }

    // MARK: - Merging stream payloads

    func testNonDiffPayloadReplacesState() {
        let current: [String: Any] = ["title": "Old", "artist": "Someone"]
        let payload: [String: Any] = ["title": "New"]

        let merged = NowPlayingStream.merge(current, payload: payload, diff: false)
        XCTAssertEqual(merged["title"] as? String, "New")
        XCTAssertNil(merged["artist"], "a non-diff payload is the whole new state")
    }

    func testDiffPayloadUpdatesChangedKeys() {
        let current: [String: Any] = ["title": "Song", "artist": "A", "playing": true]
        let payload: [String: Any] = ["playing": false]

        let merged = NowPlayingStream.merge(current, payload: payload, diff: true)
        XCTAssertEqual(merged["title"] as? String, "Song")
        XCTAssertEqual(merged["artist"] as? String, "A")
        XCTAssertEqual(merged["playing"] as? Bool, false)
    }

    func testDiffNullDropsKey() {
        let current: [String: Any] = ["title": "Song", "artist": "A"]
        let payload: [String: Any] = ["artist": NSNull()]

        let merged = NowPlayingStream.merge(current, payload: payload, diff: true)
        XCTAssertEqual(merged["title"] as? String, "Song")
        XCTAssertNil(merged["artist"], "a null value in a diff removes the key")
    }

    func testStreamSequenceEndsWithStop() {
        var state: [String: Any] = [:]

        // Full state arrives.
        state = NowPlayingStream.merge(state, payload: [
            "title": "Track", "artist": "Band", "playing": true,
        ], diff: false)
        XCTAssertEqual(NowPlayingStream.nowPlaying(from: state)?.isPlaying, true)

        // A diff pauses it.
        state = NowPlayingStream.merge(state, payload: ["playing": false], diff: true)
        XCTAssertEqual(NowPlayingStream.nowPlaying(from: state)?.isPlaying, false)

        // The title goes away: nothing is playing anymore.
        state = NowPlayingStream.merge(state, payload: ["title": NSNull()], diff: true)
        XCTAssertNil(NowPlayingStream.nowPlaying(from: state))
    }
}
