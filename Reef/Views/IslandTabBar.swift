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
                    HStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 11, weight: .semibold))
                        if selected {
                            Text(tab.title)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .fixedSize()
                        }
                    }
                    .foregroundStyle(selected ? .white : .white.opacity(0.5))
                    .padding(.horizontal, selected ? 10 : 7)
                    .frame(height: 22)
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
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        // A tinted bar so the tabs read as their own control strip rather than
        // blending into the content scrolling above them.
        .background(
            Capsule(style: .continuous)
                .fill(.black.opacity(0.4))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.3), radius: 5, y: 2))
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: current)
    }

    private func isSelected(_ tab: IslandTab) -> Bool {
        tab.page == current
    }
}
