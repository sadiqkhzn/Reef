import AppKit
import Foundation

/// One file stashed on the shelf.
struct ShelfItem: Identifiable, Equatable {
    /// Stable id from the file's path, so the same file is never added twice.
    let id: String
    let url: URL

    var name: String { url.lastPathComponent }

    init(url: URL) {
        self.url = url
        self.id = url.standardizedFileURL.path
    }
}

/// Holds the files dropped onto the island, and remembers them across launches
/// through bookmarks so a file keeps resolving even if it moves.
@MainActor
final class ShelfModel: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    private let defaults: UserDefaults
    private let key = "shelf.bookmarks"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var isEmpty: Bool { items.isEmpty }

    /// Add files, skipping any already on the shelf, newest first.
    func add(_ urls: [URL]) {
        var changed = false
        for url in urls {
            let item = ShelfItem(url: url.standardizedFileURL)
            guard !items.contains(where: { $0.id == item.id }) else { continue }
            items.insert(item, at: 0)
            changed = true
        }
        if changed { save() }
    }

    func remove(_ id: ShelfItem.ID) {
        items.removeAll { $0.id == id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    // MARK: - Persistence

    private func save() {
        let bookmarks = items.compactMap { try? $0.url.bookmarkData() }
        defaults.set(bookmarks, forKey: key)
    }

    private func load() {
        guard let bookmarks = defaults.array(forKey: key) as? [Data] else { return }
        var resolved: [ShelfItem] = []
        for data in bookmarks {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else {
                continue
            }
            // Keep only files that still exist.
            if FileManager.default.fileExists(atPath: url.path) {
                resolved.append(ShelfItem(url: url))
            }
        }
        items = resolved
        // Rewrite bookmarks so stale ones are refreshed and missing files drop.
        if resolved.count != bookmarks.count { save() }
    }
}
