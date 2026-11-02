import AppKit
import SwiftUI

/// One entry in the clipboard history.
struct ClipItem: Identifiable, Equatable {
    enum Kind { case text, link, color, code }

    let id = UUID()
    let text: String
    let date: Date
    var pinned: Bool = false

    var kind: Kind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if PickedColorParsing.hex(trimmed) != nil { return .color }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return .link
        }
        if trimmed.contains("{") || trimmed.contains(";") || trimmed.contains("func ") {
            return .code
        }
        return .text
    }

    var symbol: String {
        switch kind {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .color: return "paintpalette.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }

    /// A color when the text is a hex string, for a swatch.
    var swatch: Color? { PickedColorParsing.hex(text.trimmingCharacters(in: .whitespacesAndNewlines)) }
}

/// Tiny hex parser shared by the clipboard swatch detection.
enum PickedColorParsing {
    static func hex(_ string: String) -> Color? {
        var s = string
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = Int(s, radix: 16) else { return nil }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }
}

/// Watches the general pasteboard and keeps a searchable, pinnable history.
@MainActor
final class ClipboardModel: ObservableObject {
    @Published private(set) var items: [ClipItem] = []
    @Published var selected: ClipItem?
    @Published var search = ""
    /// Set while the model itself writes the pasteboard, so its own copy is not
    /// re-recorded as a new history entry.
    private var ignoreNextChange = false

    private var changeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private let maxItems = 80

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != changeCount else { return }
        changeCount = pb.changeCount
        if ignoreNextChange { ignoreNextChange = false; return }
        guard let text = pb.string(forType: .string),
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard items.first?.text != text else { return }

        items.removeAll { $0.text == text && !$0.pinned }
        items.insert(ClipItem(text: text, date: Date()), at: 0)
        trim()
        if selected == nil { selected = items.first }
    }

    private func trim() {
        let unpinned = items.filter { !$0.pinned }
        if unpinned.count > maxItems, let dropFrom = items.lastIndex(where: { !$0.pinned }) {
            items.remove(at: dropFrom)
        }
    }

    /// Pinned first, then the rest, filtered by the search text.
    var filtered: [ClipItem] {
        let base = items.sorted { ($0.pinned ? 1 : 0, $0.date) > ($1.pinned ? 1 : 0, $1.date) }
        guard !search.isEmpty else { return base }
        return base.filter { $0.text.localizedCaseInsensitiveContains(search) }
    }

    func select(_ item: ClipItem) { selected = item }

    func togglePin(_ item: ClipItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].pinned.toggle()
        if selected?.id == item.id { selected = items[index] }
    }

    func clear() {
        items.removeAll { !$0.pinned }
        selected = items.first
    }

    /// Put an item back on the pasteboard without re-recording it.
    func copyToPasteboard(_ item: ClipItem) {
        ignoreNextChange = true
        changeCount = NSPasteboard.general.changeCount + 1
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
    }
}
