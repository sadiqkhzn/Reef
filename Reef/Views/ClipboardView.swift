import AppKit
import SwiftUI

/// The clipboard pane: a searchable, pinnable history stream on the left and a
/// full preview of the selected item with copy/paste on the right.
struct ClipboardView: View {
    @ObservedObject var model: ClipboardModel
    var accent: Color
    var headerHeight: CGFloat
    var notchWidth: CGFloat
    /// Leave the open island (back to home).
    var onClose: () -> Void

    private var topInset: CGFloat {
        notchWidth > 0 ? headerHeight : ReefTheme.Spacing.s
    }

    var body: some View {
        VStack(spacing: ReefTheme.Spacing.s) {
            Color.clear.frame(height: topInset - ReefTheme.Spacing.s)
            HStack(alignment: .top, spacing: ReefTheme.Spacing.s) {
                // Left column owns the search row so the right inspector keeps the
                // full pane height for multi-line previews.
                VStack(spacing: ReefTheme.Spacing.s) {
                    searchRow
                    stream
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                inspector
                    .frame(width: 176)
            }
        }
        .padding(.horizontal, ReefTheme.Spacing.s)
        .padding(.bottom, 12)
    }

    // MARK: - Search

    private var searchRow: some View {
        HStack(spacing: ReefTheme.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ReefTheme.Ink.secondary)
            TextField("Search clipboard", text: $model.search)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(ReefTheme.Ink.primary)
            if !model.search.isEmpty {
                Button { model.search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(ReefTheme.Ink.tertiary)
                }
                .buttonStyle(.plain)
            }
            Button(action: model.clear) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ReefTheme.Ink.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear unpinned history")
        }
        .padding(.horizontal, ReefTheme.Spacing.m)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(.white.opacity(0.05)))
    }

    // MARK: - Stream

    private var stream: some View {
        Group {
            if model.filtered.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(ReefTheme.Ink.secondary)
                    Text(model.search.isEmpty ? "Copy something to begin" : "No matches")
                        .font(ReefTheme.Typography.caption)
                        .foregroundStyle(ReefTheme.Ink.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(model.filtered) { item in
                            row(item)
                        }
                    }
                    .padding(.bottom, 10)
                }
                .mask(
                    VStack(spacing: 0) {
                        Rectangle().fill(.black)
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 10)
                    })
            }
        }
    }

    private func row(_ item: ClipItem) -> some View {
        let isSelected = item.id == model.selected?.id
        return Button { model.select(item) } label: {
            HStack(spacing: ReefTheme.Spacing.s) {
                if let swatch = item.swatch {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(swatch)
                        .frame(width: 14, height: 14)
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                } else {
                    Image(systemName: item.symbol)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ReefTheme.Ink.secondary)
                        .frame(width: 14)
                }
                Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 11, design: item.kind == .code ? .monospaced : .default))
                    .foregroundStyle(ReefTheme.Ink.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if item.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(accent)
                }
                Text(Self.relative(item.date))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(ReefTheme.Ink.tertiary)
            }
            .padding(.horizontal, ReefTheme.Spacing.s)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.08 : 0.025)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inspector

    private var inspector: some View {
        VStack(alignment: .leading, spacing: ReefTheme.Spacing.s) {
            if let item = model.selected {
                if let swatch = item.swatch {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(swatch)
                        .frame(height: 40)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.15), lineWidth: 1))
                }
                ScrollView(showsIndicators: false) {
                    Text(item.text)
                        .font(.system(size: 11, design: item.kind == .code ? .monospaced : .default))
                        .foregroundStyle(ReefTheme.Ink.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
                Text("\(item.text.count) chars")
                    .font(.system(size: 9))
                    .foregroundStyle(ReefTheme.Ink.tertiary)
                HStack(spacing: ReefTheme.Spacing.s) {
                    action("Copy", symbol: "doc.on.doc", filled: true) {
                        model.copyToPasteboard(item)
                    }
                    action(item.pinned ? "Unpin" : "Pin", symbol: item.pinned ? "pin.slash" : "pin",
                        filled: false) {
                        model.togglePin(item)
                    }
                }
            } else {
                Text("Select an item")
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(ReefTheme.Ink.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .islandCard(padding: ReefTheme.Spacing.s)
    }

    private func action(
        _ title: String, symbol: String, filled: Bool, perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            Label(title, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(filled ? accent.contrastingInk : accent)
                .padding(.horizontal, ReefTheme.Spacing.s)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(filled ? accent : accent.opacity(0.16)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Short "now / 2m / 3h / 2d" relative label.
    private static func relative(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }
}
