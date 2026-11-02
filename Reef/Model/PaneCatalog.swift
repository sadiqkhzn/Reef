import Foundation

/// One orderable, toggleable pane that can appear as a tab in the open island.
/// Home and Now Playing are not here — Home is always pinned first and Now
/// Playing appears only while a track is on.
struct PaneSpec: Identifiable {
    let id: String
    let page: OpenPage
    let symbol: String
    let title: String
    /// A one-line description for the Settings chooser.
    let blurb: String
}

/// The catalog of panes the dock builder can order and switch on or off.
enum PaneCatalog {
    static let all: [PaneSpec] = [
        PaneSpec(id: "calendar", page: .calendar, symbol: "calendar", title: "Calendar",
            blurb: "A month grid and your upcoming agenda."),
        PaneSpec(id: "weather", page: .weather, symbol: "cloud.sun.fill", title: "Weather",
            blurb: "Current conditions, hourly, and the week."),
        PaneSpec(id: "timer", page: .timer, symbol: "timer", title: "Timer",
            blurb: "Timer and stopwatch with quick presets."),
        PaneSpec(id: "shelf", page: .shelf, symbol: "tray.fill", title: "Shelf",
            blurb: "A drop zone to stash files and drag them out."),
        PaneSpec(id: "colorPicker", page: .colorPicker, symbol: "eyedropper", title: "Color",
            blurb: "Eyedropper + recent swatches and HEX/RGB/HSL."),
        PaneSpec(id: "clipboard", page: .clipboard, symbol: "doc.on.clipboard", title: "Clipboard",
            blurb: "Searchable, pinnable copy history."),
        PaneSpec(id: "downloads", page: .downloads, symbol: "arrow.down.circle", title: "Downloads",
            blurb: "Live progress + recent files to drag out."),
        PaneSpec(id: "monitor", page: .monitor, symbol: "waveform.path.ecg", title: "Monitor",
            blurb: "Live CPU, GPU, memory, and network."),
        PaneSpec(id: "webcam", page: .webcam, symbol: "web.camera", title: "Mirror",
            blurb: "A quick front-camera check before a call."),
        PaneSpec(id: "notes", page: .notes, symbol: "note.text", title: "Notes",
            blurb: "A quick always-saved scratchpad."),
    ]

    /// Lookup by id.
    static let byID: [String: PaneSpec] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// The default tab order.
    static var defaultOrder: [String] { all.map(\.id) }

    /// The saved order reconciled against the catalog: known ids first in saved
    /// order, then any catalog panes the saved order is missing (e.g. new panes).
    static func resolvedOrder(_ saved: [String]) -> [String] {
        let known = saved.filter { byID[$0] != nil }
        let missing = all.map(\.id).filter { !known.contains($0) }
        return known + missing
    }
}
