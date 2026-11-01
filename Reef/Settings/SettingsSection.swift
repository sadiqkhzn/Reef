import SwiftUI

/// A page in the settings window, and the sidebar group it sits under.
///
/// New pages from the full settings plan (media, HUD, stats, shortcuts, and
/// the rest) are added here as their features land, so the sidebar only ever
/// lists pages that do something.
enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case appearance
    case liveActivities
    case systemHUD
    case about

    enum Group: String, CaseIterable {
        case core = "Core"
        case info = "Info"
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .liveActivities: return "Live Activities"
        case .systemHUD: return "System HUD"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .liveActivities: return "capsule.inset.filled"
        case .systemHUD: return "slider.horizontal.3"
        case .about: return "info.circle.fill"
        }
    }

    /// Color of the rounded tile behind the sidebar icon.
    var tint: Color {
        switch self {
        case .general: return .gray
        case .appearance: return .indigo
        case .liveActivities: return .teal
        case .systemHUD: return .orange
        case .about: return .blue
        }
    }

    var group: Group {
        switch self {
        case .general, .appearance, .liveActivities, .systemHUD: return .core
        case .about: return .info
        }
    }

    /// Extra words the sidebar search matches, beyond the title.
    var keywords: [String] {
        switch self {
        case .general:
            return ["login", "startup", "attached", "floating", "position", "notch", "style"]
        case .appearance:
            return ["glass", "liquid", "frosted", "midnight", "material", "theme", "accent",
                    "color", "motion", "animation", "spring"]
        case .liveActivities:
            return ["battery", "charging", "low", "wings", "activity", "airpods", "bluetooth", "devices", "headphones"]
        case .systemHUD:
            return ["volume", "brightness", "hud", "osd", "overlay", "sound", "keys", "mute", "sliders"]
        case .about:
            return ["version", "credits", "license", "github"]
        }
    }

    /// True when `query` is empty or appears in the title or keywords,
    /// ignoring case.
    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        if title.localizedCaseInsensitiveContains(trimmed) { return true }
        return keywords.contains { $0.localizedCaseInsensitiveContains(trimmed) }
    }
}
