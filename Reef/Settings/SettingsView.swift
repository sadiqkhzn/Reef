import SwiftUI

/// Placeholder settings pane.
///
/// A real settings window with per-feature toggles lands in a later version.
/// For now this gives the Settings scene something to show so Cmd+comma and the
/// menu bar item have a destination.
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "water.waves")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.secondary)

            Text("Reef")
                .font(.title2.weight(.semibold))

            Text("Settings are coming in a later version.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(width: 360, height: 200)
    }
}

#Preview {
    SettingsView()
}
