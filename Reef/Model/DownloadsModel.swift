import AppKit
import SwiftUI

/// A file in the Downloads folder — either an in-progress download (a browser
/// temp file) or a finished one.
struct DownloadItem: Identifiable, Equatable {
    var id: URL { url }
    let url: URL
    let name: String
    let size: Int64
    let isActive: Bool
    let date: Date
    /// Bytes per second while active, when it can be measured.
    var speed: Double?

    static func == (lhs: DownloadItem, rhs: DownloadItem) -> Bool {
        lhs.url == rhs.url && lhs.size == rhs.size && lhs.isActive == rhs.isActive
    }
}

/// Watches the Downloads folder: surfaces in-progress downloads with a live
/// speed estimate and the most recent finished files.
@MainActor
final class DownloadsModel: ObservableObject {
    @Published private(set) var active: [DownloadItem] = []
    @Published private(set) var completed: [DownloadItem] = []

    private var timer: Timer?
    private var lastSizes: [URL: (size: Int64, at: Date)] = [:]
    private let inProgressExtensions: Set<String> = ["crdownload", "download", "part", "tmp"]

    func start() {
        guard timer == nil else { return }
        scan()
        timer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scan() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scan() {
        guard let dir = FileManager.default.urls(
            for: .downloadsDirectory, in: .userDomainMask).first else { return }
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]) else { return }

        var actives: [DownloadItem] = []
        var dones: [DownloadItem] = []
        let now = Date()

        for url in urls {
            let values = try? url.resourceValues(forKeys: keys)
            if values?.isDirectory == true { continue }
            let size = Int64(values?.fileSize ?? 0)
            let modified = values?.contentModificationDate ?? .distantPast
            let ext = url.pathExtension.lowercased()

            if inProgressExtensions.contains(ext) {
                var speed: Double?
                if let last = lastSizes[url] {
                    let dt = now.timeIntervalSince(last.at)
                    if dt > 0.3 { speed = max(0, Double(size - last.size) / dt) }
                }
                lastSizes[url] = (size, now)
                actives.append(DownloadItem(
                    url: url, name: cleanName(url), size: size, isActive: true,
                    date: modified, speed: speed))
            } else {
                dones.append(DownloadItem(
                    url: url, name: url.lastPathComponent, size: size, isActive: false,
                    date: modified))
            }
        }

        // Forget temp files that finished.
        let activeURLs = Set(actives.map(\.url))
        lastSizes = lastSizes.filter { activeURLs.contains($0.key) }

        active = actives.sorted { $0.date > $1.date }
        completed = dones.sorted { $0.date > $1.date }.prefix(8).map { $0 }
    }

    /// Strip the browser temp suffix for display.
    private func cleanName(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
