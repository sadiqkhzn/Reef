import SwiftUI

/// One entry in the open island's tab bar.
struct IslandTab: Identifiable, Equatable {
    let page: OpenPage
    let symbol: String
    let title: String
    var id: String { title }
}

/// The open island's navigation: a centered row of icon tabs. The selected tab
/// fills with the accent and reveals its short label; the fill slides between
/// tabs via a matched-geometry pill.
struct IslandTabBar: View {
    let tabs: [IslandTab]
    /// The page currently shown (used to light the matching tab).
    let current: OpenPage
    var accent: Color
    let onSelect: (OpenPage) -> Void

    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                let selected = isSelected(tab)
                Button { onSelect(tab.page) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 13, weight: .semibold))
                        if selected {
                            Text(tab.title)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .fixedSize()
                        }
                    }
                    .foregroundStyle(selected ? .white : .white.opacity(0.5))
                    .padding(.horizontal, selected ? 12 : 9)
                    .frame(height: 26)
                    .background {
                        if selected {
                            Capsule()
                                .fill(accent.opacity(0.9))
                                .matchedGeometryEffect(id: "tabpill", in: ns)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: current)
    }

    /// The Now-Playing tab also owns the bare "home" state (no track playing).
    private func isSelected(_ tab: IslandTab) -> Bool {
        if tab.page == .nowPlaying { return current == .nowPlaying || current == .home }
        return tab.page == current
    }
}
