import AppKit
import SwiftUI

/// The downloads pane: an active-download hero card (when one is running) over
/// a list of recently finished files that can be dragged straight out.
struct DownloadsView: View {
    @ObservedObject var model: DownloadsModel
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

            if let item = model.active.first {
                activeCard(item)
            }

            if model.completed.isEmpty && model.active.isEmpty {
                empty
            } else {
                completedList
            }
        }
        .padding(.horizontal, ReefTheme.Spacing.s)
        .padding(.bottom, 12)
    }

    // MARK: - Active

    private func activeCard(_ item: DownloadItem) -> some View {
        VStack(spacing: ReefTheme.Spacing.s) {
            HStack(spacing: ReefTheme.Spacing.m) {
                fileIcon(item.url, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ReefTheme.Ink.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(telemetry(item))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(ReefTheme.Ink.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accent)
                    .symbolEffect(.pulse, options: .repeating)
            }
            indeterminateBar
        }
        .islandCard(padding: ReefTheme.Spacing.m)
    }

    private func telemetry(_ item: DownloadItem) -> String {
        var parts = [DownloadsModel.formatBytes(item.size)]
        if let speed = item.speed, speed > 0 {
            parts.append("\(DownloadsModel.formatBytes(Int64(speed)))/s")
        }
        return parts.joined(separator: "  •  ")
    }

    private var indeterminateBar: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = CGFloat((t.truncatingRemainder(dividingBy: 1.2)) / 1.2)
            GeometryReader { geo in
                Capsule().fill(.white.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Capsule().fill(accent)
                            .frame(width: geo.size.width * 0.35)
                            .offset(x: (geo.size.width + geo.size.width * 0.35) * phase - geo.size.width * 0.35)
                    }
                    .clipShape(Capsule())
            }
            .frame(height: 3)
        }
    }

    // MARK: - Completed

    private var completedList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 3) {
                ForEach(model.completed) { item in
                    completedRow(item)
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

    private func completedRow(_ item: DownloadItem) -> some View {
        HStack(spacing: ReefTheme.Spacing.s) {
            fileIcon(item.url, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ReefTheme.Ink.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(DownloadsModel.formatBytes(item.size))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(ReefTheme.Ink.tertiary)
            }
            Spacer(minLength: 0)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ReefTheme.Ink.secondary)
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
        }
        .padding(.horizontal, ReefTheme.Spacing.s)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.03)))
        .contentShape(Rectangle())
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
    }

    private var empty: some View {
        VStack(spacing: 4) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(ReefTheme.Ink.secondary)
            Text("No recent downloads")
                .font(ReefTheme.Typography.caption)
                .foregroundStyle(ReefTheme.Ink.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fileIcon(_ url: URL, size: CGFloat) -> some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .frame(width: size, height: size)
    }
}
