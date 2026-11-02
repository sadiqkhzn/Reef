import SwiftUI

/// The dock builder: choose which panes appear as tabs in the open island and
/// drag them into the order you want.
struct PanesSettingsPage: View {
    @EnvironmentObject private var settings: ReefSettings

    private var orderedSpecs: [PaneSpec] {
        PaneCatalog.resolvedOrder(settings.paneOrder).compactMap { PaneCatalog.byID[$0] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Panes")
                    .font(.title2.bold())
                Text("Drag to reorder the tabs, and switch panes on or off. Home and Now Playing are always available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)

            List {
                ForEach(orderedSpecs) { spec in
                    PaneRow(
                        spec: spec,
                        isOn: Binding(
                            get: { settings.isPaneEnabled(spec.id) },
                            set: { settings.setPaneEnabled(spec.id, $0) }))
                }
                .onMove(perform: move)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var order = PaneCatalog.resolvedOrder(settings.paneOrder)
        order.move(fromOffsets: source, toOffset: destination)
        settings.paneOrder = order
    }
}

private struct PaneRow: View {
    let spec: PaneSpec
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)

            Image(systemName: spec.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isOn ? Color.accentColor.gradient : Color.secondary.opacity(0.4).gradient))

            VStack(alignment: .leading, spacing: 1) {
                Text(spec.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(spec.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
        .opacity(isOn ? 1 : 0.6)
    }
}
