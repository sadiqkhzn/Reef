import Foundation

/// Trims the noise many sources (especially YouTube) append to track titles —
/// "(Official Music Video)", "[Lyrics]", "| Full Song", " - Topic" — while
/// leaving the real title and genuine parentheticals (like "(Live)" or a
/// "feat." credit) intact.
enum TitleCleaner {
    /// Keywords that mark a bracketed group as noise worth removing.
    private static let noise = [
        "official video", "official music video", "official audio", "official lyric",
        "official visualizer", "music video", "lyric video", "lyrics video",
        "with lyrics", "lyrics", "lyric", "audio only", "visualizer", "official",
        "hd", "4k", "hq", "remaster", "remastered", "explicit", "clean version",
        "full song", "full video", "full audio", "color coded", "clip officiel",
        "mv", "m/v", "video oficial",
    ]

    static func clean(_ title: String) -> String {
        var result = title

        // Remove (...) and [...] groups whose contents read as noise.
        for (open, close) in [("(", ")"), ("[", "]")] {
            result = removeBracketedNoise(result, open: open, close: close)
        }

        // Drop a trailing " - Topic" (YouTube auto-generated artist channels).
        if result.hasSuffix(" - Topic") {
            result = String(result.dropLast(" - Topic".count))
        }

        // Collapse whitespace and trim stray separators left behind.
        result = result.replacingOccurrences(
            of: "\\s{2,}", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: " -|•·"))
        result = result.trimmingCharacters(in: .whitespaces)

        // Never return empty — fall back to the original.
        return result.isEmpty ? title : result
    }

    private static func removeBracketedNoise(_ text: String, open: String, close: String) -> String {
        let pattern = "\\s*\\\(open)[^\\\(open)\\\(close)]*\\\(close)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        let ns = text as NSString
        var output = ""
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let group = ns.substring(with: match.range).lowercased()
            let isNoise = noise.contains { group.contains($0) }
            if isNoise {
                // Append text before this group, skip the group.
                output += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                cursor = match.range.location + match.range.length
            }
        }
        output += ns.substring(from: cursor)
        return output
    }
}
