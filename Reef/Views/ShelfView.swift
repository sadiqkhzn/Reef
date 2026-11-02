import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The shelf page in a wide two-pane layout.
///
/// Left pane: an AirDrop target — drop files on it to send them. Right pane: the
/// shelf itself, where dropped files are stashed and can be dragged back out to
/// Finder or another app.
struct ShelfView: View {
    @ObservedObject var shelf: ShelfModel
    var accent: Color
    var headerHeight: CGFloat
    var notchWidth: CGFloat
    /// Leave the open island (back to home).
    var onClose: () -> Void

    @State private var airdropTargeted = false
    @State private var shelfTargeted = false

    /// Top clearance: the full header height to clear the notch in the attached
    /// style, or a small inset when floating so there is no dead space.
    private var topInset: CGFloat {
        notchWidth > 0 ? headerHeight : ReefTheme.Spacing.s
    }

    private let columns = [GridItem(.adaptive(minimum: 68), spacing: ReefTheme.Spacing.s)]

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)
            HStack(alignment: .top, spacing: ReefTheme.Spacing.s) {
                airdropPane
                    .frame(width: 168)
                shelfPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, ReefTheme.Spacing.s)
            .padding(.bottom, ReefTheme.Spacing.s)
        }
    }

    // MARK: - AirDrop pane

    private var airdropPane: some View {
        VStack(spacing: 6) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(airdropTargeted ? accent : ReefTheme.Ink.primary)
            Text("AirDrop")
                .font(ReefTheme.Typography.caption)
                .foregroundStyle(ReefTheme.Ink.primary)
            Text("Drop to send")
                .font(.system(size: 9))
                .foregroundStyle(ReefTheme.Ink.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dashedTarget(on: airdropTargeted))
        .onDrop(of: [UTType.fileURL], isTargeted: $airdropTargeted) { providers in
            airdrop(providers)
        }
    }

    // MARK: - Shelf pane

    private var shelfPane: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if shelf.isEmpty {
                    empty
                } else {
                    files
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !shelf.isEmpty {
                Button(action: shelf.clear) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ReefTheme.Ink.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Clear the shelf")
                .padding(6)
            }
        }
        .background(dashedTarget(on: shelfTargeted))
        .onDrop(of: [UTType.fileURL], isTargeted: $shelfTargeted) { providers in
            addToShelf(providers)
        }
    }

    private var empty: some View {
        VStack(spacing: 4) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(ReefTheme.Ink.secondary)
            Text("Drop files here")
                .font(ReefTheme.Typography.caption)
                .foregroundStyle(ReefTheme.Ink.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var files: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: ReefTheme.Spacing.s) {
                ForEach(shelf.items) { item in
                    FileChip(item: item) { shelf.remove(item.id) }
                }
            }
            .padding(ReefTheme.Spacing.s)
        }
    }

    // MARK: - Drop handling

    /// Send the dropped files via the system AirDrop sheet.
    private func airdrop(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !fileProviders.isEmpty else { return false }

        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in fileProviders {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url, url.isFileURL { urls.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            guard !urls.isEmpty,
                let service = NSSharingService(named: .sendViaAirDrop) else { return }
            service.perform(withItems: urls)
        }
        return true
    }

    /// Stash the dropped files on the shelf.
    private func addToShelf(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !fileProviders.isEmpty else { return false }

        for provider in fileProviders {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.isFileURL else { return }
                Task { @MainActor in shelf.add([url]) }
            }
        }
        return true
    }

    private func dashedTarget(on highlighted: Bool) -> some View {
        RoundedRectangle(cornerRadius: ReefTheme.Radius.card, style: .continuous)
            .fill(accent.opacity(highlighted ? 0.1 : 0))
            .overlay(
                RoundedRectangle(cornerRadius: ReefTheme.Radius.card, style: .continuous)
                    .strokeBorder(
                        (highlighted ? accent : ReefTheme.Ink.secondary)
                            .opacity(highlighted ? 0.8 : 0.3),
                        style: StrokeStyle(lineWidth: 1, dash: [4])))
    }
}

/// One file on the shelf: its icon and name, draggable out, with a remove badge
/// on hover.
private struct FileChip: View {
    let item: ShelfItem
    var onRemove: () -> Void

    @State private var hovered = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 40, height: 40)
            Text(item.name)
                .font(.system(size: 9))
                .foregroundStyle(ReefTheme.Ink.secondary)
                .lineLimit(1)
                .frame(width: 60)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ReefTheme.Ink.fill))
        .overlay(alignment: .topTrailing) {
            if hovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white, .black.opacity(0.5))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }
        }
        .onHover { hovered = $0 }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
    }
}
