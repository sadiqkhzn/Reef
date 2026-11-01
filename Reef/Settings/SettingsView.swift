import SwiftUI

/// The settings window.
///
/// A grouped, searchable list of pages on the left and the selected page on
/// the right, laid out like System Settings so it feels at home on macOS.
struct SettingsView: View {
    @State private var selection: SettingsSection? = .appearance
    @State private var query = ""

    private var visibleSections: [SettingsSection] {
        SettingsSection.allCases.filter { $0.matches(query) }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            detail
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(SettingsSection.Group.allCases, id: \.self) { group in
                let sections = visibleSections.filter { $0.group == group }
                if !sections.isEmpty {
                    Section(group.rawValue) {
                        ForEach(sections) { section in
                            SidebarRow(section: section)
                                .tag(section)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, placement: .sidebar, prompt: "Search")
        .overlay {
            if visibleSections.isEmpty {
                Text("No results")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general:
            GeneralSettingsPage()
        case .appearance:
            AppearanceSettingsPage()
        case .liveActivities:
            LiveActivitySettingsPage()
        case .systemHUD:
            SystemHUDSettingsPage()
        case .ambient:
            AmbientSettingsPage()
        case .about:
            AboutSettingsPage()
        case nil:
            Text("Select a section")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// A sidebar entry with its icon on a colored rounded tile.
private struct SidebarRow: View {
    var section: SettingsSection

    var body: some View {
        Label {
            Text(section.title)
        } icon: {
            Image(systemName: section.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(section.tint.gradient))
        }
    }
}
