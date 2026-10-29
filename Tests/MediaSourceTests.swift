import XCTest
@testable import Reef

/// Covers the source filter and the frontmost-app rule that decide whether the
/// island shows a track.
final class MediaSourceTests: XCTestCase {

    private func track(_ bundle: String?) -> NowPlaying {
        NowPlaying(title: "Song", artist: "", album: "", isPlaying: true, bundleIdentifier: bundle)
    }

    // MARK: - Source filter

    func testAutomaticAllowsAnyApp() {
        XCTAssertTrue(MediaSource.automatic.allows(bundleIdentifier: "com.apple.Music"))
        XCTAssertTrue(MediaSource.automatic.allows(bundleIdentifier: "com.spotify.client"))
        XCTAssertTrue(MediaSource.automatic.allows(bundleIdentifier: nil))
    }

    func testAppleMusicOnlyAllowsMusic() {
        XCTAssertTrue(MediaSource.appleMusic.allows(bundleIdentifier: "com.apple.Music"))
        XCTAssertFalse(MediaSource.appleMusic.allows(bundleIdentifier: "com.spotify.client"))
    }

    func testSpotifyOnlyAllowsSpotify() {
        XCTAssertTrue(MediaSource.spotify.allows(bundleIdentifier: "com.spotify.client"))
        XCTAssertFalse(MediaSource.spotify.allows(bundleIdentifier: "com.apple.Music"))
    }

    // MARK: - Gate

    func testGateHidesNonMatchingSource() {
        let shown = MediaGate.shownTrack(
            track("com.spotify.client"),
            source: .appleMusic,
            hideWhenSourceFrontmost: false,
            frontmostBundleIdentifier: nil)
        XCTAssertNil(shown)
    }

    func testGateShowsMatchingSource() {
        let shown = MediaGate.shownTrack(
            track("com.apple.Music"),
            source: .appleMusic,
            hideWhenSourceFrontmost: false,
            frontmostBundleIdentifier: "com.apple.Finder")
        XCTAssertEqual(shown?.bundleIdentifier, "com.apple.Music")
    }

    func testGateHidesWhenSourceAppIsFrontmost() {
        let shown = MediaGate.shownTrack(
            track("com.apple.Music"),
            source: .automatic,
            hideWhenSourceFrontmost: true,
            frontmostBundleIdentifier: "com.apple.Music")
        XCTAssertNil(shown, "its own app is frontmost, so the island steps aside")
    }

    func testGateShowsWhenAnotherAppIsFrontmost() {
        let shown = MediaGate.shownTrack(
            track("com.apple.Music"),
            source: .automatic,
            hideWhenSourceFrontmost: true,
            frontmostBundleIdentifier: "com.apple.Safari")
        XCTAssertEqual(shown?.bundleIdentifier, "com.apple.Music")
    }

    func testGateWithNoTrackIsNil() {
        XCTAssertNil(MediaGate.shownTrack(
            nil, source: .automatic, hideWhenSourceFrontmost: false, frontmostBundleIdentifier: nil))
    }
}
