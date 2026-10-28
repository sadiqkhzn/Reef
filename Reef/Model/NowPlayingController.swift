import AppKit
import Foundation

/// Reads system-wide now playing information and relays transport commands.
///
/// It launches the bundled MediaRemote adapter through the system Perl binary
/// and reads its JSON stream, so it sees whatever is playing in any app or
/// browser. All parsing, merging, and artwork decoding happen on a background
/// queue; only the finished `NowPlaying` is handed to the main thread, so the
/// overlay never stutters. See `Reef/Vendor/mediaremote-adapter`.
final class NowPlayingController: ObservableObject {
    @Published private(set) var current: NowPlaying?

    private let scriptPath: String?
    private let frameworkPath: String?
    private var streamProcess: Process?

    /// Everything below is touched only on `queue`.
    private let queue = DispatchQueue(label: "dev.sadiqkhzn.Reef.nowplaying")
    private var state: [String: Any] = [:]
    private var buffer = Data()
    private var lastPublished: NowPlaying?
    private var lastArtworkEncoded: String?
    private var lastArtworkImage: NSImage?

    /// MediaRemote command ids used by the adapter's `send` command.
    private enum CommandID: Int {
        case togglePlayPause = 2
        case nextTrack = 4
        case previousTrack = 5
    }

    init() {
        scriptPath = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl")?.path
        frameworkPath = Bundle.main.privateFrameworksURL?
            .appendingPathComponent("MediaRemoteAdapter.framework").path
        startStream()
    }

    deinit {
        streamProcess?.terminate()
    }

    // MARK: - Stream

    private func startStream() {
        guard let scriptPath, let frameworkPath else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptPath, frameworkPath, "stream", "--micros"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async { self?.ingest(data) }
        }

        do {
            try process.run()
            streamProcess = process
        } catch {
            streamProcess = nil
        }
    }

    /// Runs on `queue`.
    private func ingest(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            handleLine(line)
        }
    }

    /// Runs on `queue`. Builds the next `NowPlaying` and publishes it only when
    /// it differs from the last one, so the UI is left alone otherwise.
    private func handleLine(_ line: Data) {
        guard !line.isEmpty,
            let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
            (object["type"] as? String) == "data" else {
            return
        }

        let diff = (object["diff"] as? Bool) ?? false
        let payload = (object["payload"] as? [String: Any]) ?? [:]
        state = NowPlayingStream.merge(state, payload: payload, diff: diff)

        var next = NowPlayingStream.nowPlaying(from: state)
        if next != nil {
            let encoded = NowPlayingStream.encodedArtwork(from: state)
            next?.artwork = artworkImage(for: encoded)
            next?.artworkToken = encoded?.hashValue
        }

        guard next != lastPublished else { return }
        lastPublished = next

        let bundleIdentifier = next?.bundleIdentifier
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var enriched = next
            enriched?.appName = Self.appName(for: bundleIdentifier)
            self.current = enriched
        }
    }

    /// Runs on `queue`. Decodes the artwork image only when the encoded string
    /// changes, so it is never decoded during a render.
    private func artworkImage(for encoded: String?) -> NSImage? {
        guard let encoded else {
            lastArtworkEncoded = nil
            lastArtworkImage = nil
            return nil
        }
        if encoded == lastArtworkEncoded {
            return lastArtworkImage
        }
        let image = Data(base64Encoded: encoded).flatMap { NSImage(data: $0) }
        lastArtworkEncoded = encoded
        lastArtworkImage = image
        return image
    }

    /// Resolve a readable app name from a bundle id using the running app list.
    private static func appName(for bundleIdentifier: String?) -> String? {
        guard let bundleIdentifier else { return nil }
        return NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first?
            .localizedName
    }

    // MARK: - Controls

    func playPause() { send(.togglePlayPause) }
    func next() { send(.nextTrack) }
    func previous() { send(.previousTrack) }

    private func send(_ command: CommandID) {
        guard let scriptPath, let frameworkPath else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptPath, frameworkPath, "send", String(command.rawValue)]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}
