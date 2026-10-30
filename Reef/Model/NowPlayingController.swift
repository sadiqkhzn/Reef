import AppKit
import Foundation
import SwiftUI

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
    /// Pending clear of the now playing during a track gap.
    private var clearWork: DispatchWorkItem?
    private var lastArtworkEncoded: String?
    private var lastArtworkImage: NSImage?
    private var lastArtworkTint: Color?

    /// MediaRemote command ids used by the adapter's `send` command.
    private enum CommandID: Int {
        case togglePlayPause = 2
        case nextTrack = 4
        case previousTrack = 5
        case cycleShuffle = 6
        case cycleRepeat = 7
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
            next?.tint = lastArtworkTint
        }

        if next == nil {
            // A track change briefly clears the title between songs. Hold the
            // last track for a short window rather than blinking to empty; a new
            // track within the window cancels the clear, and a real stop lets it
            // through.
            guard lastPublished != nil else { return }
            scheduleClear()
            return
        }

        clearWork?.cancel()
        clearWork = nil
        publish(next)
    }

    /// Runs on `queue`. Clear the now playing after a short grace, unless a
    /// track has resumed by then.
    private func scheduleClear() {
        clearWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if NowPlayingStream.nowPlaying(from: self.state) == nil {
                self.publish(nil)
            }
        }
        clearWork = work
        queue.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    /// Runs on `queue`. Publish a track to the main thread only when it differs
    /// from the last one.
    private func publish(_ track: NowPlaying?) {
        guard track != lastPublished else { return }
        lastPublished = track

        let bundleIdentifier = track?.bundleIdentifier
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var enriched = track
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
            lastArtworkTint = nil
            return nil
        }
        if encoded == lastArtworkEncoded {
            return lastArtworkImage
        }
        let image = Data(base64Encoded: encoded).flatMap { NSImage(data: $0) }
        lastArtworkEncoded = encoded
        lastArtworkImage = image
        lastArtworkTint = image?.reefVibrantColor
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
    func toggleShuffle() { send(.cycleShuffle) }
    func cycleRepeat() { send(.cycleRepeat) }

    /// Jump the current track to a position in seconds.
    func seek(to seconds: TimeInterval) {
        let micros = Int(max(0, seconds) * 1_000_000)
        run(["seek", String(micros)])
    }

    private func send(_ command: CommandID) {
        run(["send", String(command.rawValue)])
    }

    /// Fire a one-shot adapter subcommand. Each call is its own short-lived
    /// process, matching how the adapter's `send`/`seek` verbs are invoked.
    private func run(_ arguments: [String]) {
        guard let scriptPath, let frameworkPath else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptPath, frameworkPath] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}

extension NSImage {
    /// A vivid color that stands for the cover.
    ///
    /// The image is drawn small, then the pixels are averaged with a weight that
    /// favors saturated, bright ones, so a muted background does not wash the
    /// result out. The most vivid single pixel is the fallback. The result is
    /// lifted in saturation and brightness so it reads on the dark island.
    var reefVibrantColor: Color? {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

        var sumR = 0.0, sumG = 0.0, sumB = 0.0, weightSum = 0.0
        var bestScore = -1.0, bestR = 1.0, bestG = 1.0, bestB = 1.0

        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[i]) / 255
            let g = Double(pixels[i + 1]) / 255
            let b = Double(pixels[i + 2]) / 255
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let saturation = maxC <= 0 ? 0 : (maxC - minC) / maxC
            let weight = saturation * saturation * maxC
            sumR += r * weight
            sumG += g * weight
            sumB += b * weight
            weightSum += weight

            let score = saturation * maxC
            if score > bestScore {
                bestScore = score
                bestR = r
                bestG = g
                bestB = b
            }
        }

        var r = bestR, g = bestG, b = bestB
        if weightSum > 0.0001 {
            r = sumR / weightSum
            g = sumG / weightSum
            b = sumB / weightSum
        }

        let base = NSColor(red: r, green: g, blue: b, alpha: 1)
        guard let device = base.usingColorSpace(.deviceRGB) else { return Color(nsColor: base) }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
        device.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        let lifted = NSColor(
            hue: hue,
            saturation: max(0.55, saturation),
            brightness: max(0.82, brightness),
            alpha: 1)
        return Color(nsColor: lifted)
    }
}
