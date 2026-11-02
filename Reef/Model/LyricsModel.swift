import Foundation

/// Fetches time-synced lyrics for the current track from LRCLIB — a free,
/// keyless, open lyrics API — and parses the LRC timings so the Now Playing
/// hero can follow along.
@MainActor
final class LyricsModel: ObservableObject {
    /// One timed lyric line.
    struct Line: Identifiable, Equatable {
        let id = UUID()
        let time: TimeInterval
        let text: String
    }

    enum LoadState: Equatable { case idle, loading, loaded, unavailable }

    @Published private(set) var lines: [Line] = []
    /// Unsynced lyrics, used when the track only has a plain transcript.
    @Published private(set) var plain: String?
    @Published private(set) var state: LoadState = .idle

    /// True when there is anything to show.
    var hasLyrics: Bool { !lines.isEmpty || plain != nil }
    /// True when the lyrics carry timings and can scroll with playback.
    var isSynced: Bool { !lines.isEmpty }

    private var currentKey: String?
    private var task: Task<Void, Never>?

    /// Load lyrics for a track, keyed by title+artist so the same song isn't
    /// refetched. Clears to "unavailable" when there isn't enough to search on.
    func load(title: String, artist: String, album: String, duration: TimeInterval?) {
        let key = "\(title)|\(artist)"
        guard key != currentKey else { return }
        currentKey = key
        task?.cancel()
        lines = []
        plain = nil

        guard !title.isEmpty, !artist.isEmpty else {
            state = .unavailable
            return
        }
        state = .loading
        task = Task { [key] in
            await fetch(title: title, artist: artist, album: album, duration: duration, key: key)
        }
    }

    /// The index of the line that should be highlighted at `position`, i.e. the
    /// last line whose timestamp has passed.
    func activeIndex(at position: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        var index: Int?
        for (i, line) in lines.enumerated() {
            if line.time <= position { index = i } else { break }
        }
        return index
    }

    // MARK: - Fetch

    private func fetch(
        title: String, artist: String, album: String, duration: TimeInterval?, key: String
    ) async {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        var items = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]
        if !album.isEmpty { items.append(URLQueryItem(name: "album_name", value: album)) }
        if let duration, duration > 0 {
            items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        components?.queryItems = items
        guard let url = components?.url else {
            finish(key: key, state: .unavailable)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue(
            "Reef (https://github.com/sadiqkhzn/Reef)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard key == currentKey else { return }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                finish(key: key, state: .unavailable)
                return
            }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            if let synced = decoded.syncedLyrics, !synced.isEmpty {
                let parsed = Self.parseLRC(synced)
                if !parsed.isEmpty {
                    lines = parsed
                    state = .loaded
                    return
                }
            }
            if let plainText = decoded.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines),
                !plainText.isEmpty {
                plain = plainText
                state = .loaded
                return
            }
            state = .unavailable
        } catch {
            guard key == currentKey else { return }
            state = .unavailable
        }
    }

    private func finish(key: String, state newState: LoadState) {
        guard key == currentKey else { return }
        state = newState
    }

    /// Parse LRC text ("[mm:ss.xx] line") into timed lines, honoring multiple
    /// timestamps on one line and skipping metadata tags.
    static func parseLRC(_ raw: String) -> [Line] {
        var result: [Line] = []
        for rawLine in raw.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            var stamps: [TimeInterval] = []
            var searchRange = line.startIndex..<line.endIndex
            while let open = line.range(of: "[", range: searchRange),
                let close = line.range(of: "]", range: open.upperBound..<line.endIndex) {
                let tag = String(line[open.upperBound..<close.lowerBound])
                if let seconds = timestamp(tag) { stamps.append(seconds) }
                searchRange = close.upperBound..<line.endIndex
                // Only consecutive leading tags count as timestamps.
                if !stamps.isEmpty, close.upperBound < line.endIndex,
                    line[close.upperBound] != "[" { break }
            }
            guard !stamps.isEmpty else { continue }
            let text = line
                .replacingOccurrences(
                    of: "\\[[^\\]]*\\]", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            for stamp in stamps {
                result.append(Line(time: stamp, text: text))
            }
        }
        return result.sorted { $0.time < $1.time }
    }

    /// Convert an LRC timestamp "mm:ss.xx" (or "mm:ss") to seconds; nil for tags.
    private static func timestamp(_ tag: String) -> TimeInterval? {
        let parts = tag.split(separator: ":")
        guard parts.count == 2, let minutes = Double(parts[0]) else { return nil }
        guard let seconds = Double(parts[1].replacingOccurrences(of: ",", with: ".")) else {
            return nil
        }
        return minutes * 60 + seconds
    }

    /// The slice of the LRCLIB response Reef reads.
    private struct Response: Decodable {
        let plainLyrics: String?
        let syncedLyrics: String?
    }
}
