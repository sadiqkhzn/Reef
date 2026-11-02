import SwiftUI

/// Choose which optional panes appear as tabs in the open island.
struct PanesSettingsPage: View {
    @EnvironmentObject private var settings: ReefSettings

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Panes")
                        .font(.title2.bold())
                    Text("Pick the tabs that show in the open island. Home and Now Playing are always available.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PaneOption.all) { option in
                        PaneCard(option: option, isOn: binding(for: option))
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func binding(for option: PaneOption) -> Binding<Bool> {
        switch option.id {
        case "colorPicker": return $settings.showsColorPicker
        case "clipboard": return $settings.showsClipboard
        case "downloads": return $settings.showsDownloads
        case "monitor": return $settings.showsMonitor
        case "webcam": return $settings.showsWebcam
        case "notes": return $settings.showsNotes
        default: return .constant(true)
        }
    }
}

/// A togglable optional pane, with its marketing blurb for the chooser.
struct PaneOption: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let blurb: String
    let tint: Color

    static let all: [PaneOption] = [
        PaneOption(id: "colorPicker", title: "Color Picker", symbol: "eyedropper",
            blurb: "Eyedropper + recent swatches and HEX/RGB/HSL.", tint: .pink),
        PaneOption(id: "clipboard", title: "Clipboard", symbol: "doc.on.clipboard",
            blurb: "Searchable, pinnable copy history.", tint: .orange),
        PaneOption(id: "downloads", title: "Downloads", symbol: "arrow.down.circle",
            blurb: "Live progress + recent files to drag out.", tint: .green),
        PaneOption(id: "monitor", title: "System Monitor", symbol: "waveform.path.ecg",
            blurb: "Live CPU, memory, and network telemetry.", tint: .red),
        PaneOption(id: "webcam", title: "Mirror", symbol: "web.camera",
            blurb: "A quick front-camera check before a call.", tint: .blue),
        PaneOption(id: "notes", title: "Notes", symbol: "note.text",
            blurb: "A quick always-saved scratchpad.", tint: .yellow),
    ]
}

private struct PaneCard: View {
    let option: PaneOption
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: option.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(option.tint.gradient))
                    Spacer()
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(isOn ? Color.accentColor : .secondary.opacity(0.5))
                }
                Text(option.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(option.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .opacity(isOn ? 1 : 0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isOn ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.15),
                        lineWidth: isOn ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.18), value: isOn)
    }
}
