import AppKit
import SwiftUI

/// The shelf page: files stashed on the island, each able to be dragged back
/// out to Finder or another app. Empty, it invites a drop.
struct ShelfView: View {
    @ObservedObject var shelf: ShelfModel
    var accent: Color
    var headerHeight: CGFloat
    var notchWidth: CGFloat
    /// Leave the open island (back to home).
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: headerHeight)

            if shelf.isEmpty {
                empty
            } else {
                files
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("Shelf")
                .font(ReefTheme.Typography.caption)
                .foregroundStyle(accent)
                .padding(.horizontal, ReefTheme.Spacing.s)
                .padding(.vertical, 3)
                .background(Capsule().fill(accent.opacity(0.18)))

            Spacer(minLength: notchWidth + ReefTheme.Spacing.l)

            if !shelf.isEmpty {
                Button(action: shelf.clear) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ReefTheme.Ink.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Clear the shelf")
            }
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ReefTheme.Spacing.s) {
                ForEach(shelf.items) { item in
                    FileChip(item: item) { shelf.remove(item.id) }
                }
            }
            .padding(.horizontal, ReefTheme.Spacing.l)
            .padding(.vertical, 6)
        }
        .frame(maxHeight: .infinity)
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
