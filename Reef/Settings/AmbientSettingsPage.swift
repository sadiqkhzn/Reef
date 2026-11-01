import SwiftUI

/// Controls for the full-screen ambient display that appears when the Mac is
/// idle and unlocked.
struct AmbientSettingsPage: View {
    @EnvironmentObject private var settings: ReefSettings
    @EnvironmentObject private var ambient: AmbientController

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.ambientEnabled) {
                    Label("Show when idle", systemImage: "moon.stars.fill")
                }
                if settings.ambientEnabled {
                    Picker("After", selection: $settings.ambientIdleMinutes) {
                        Text("1 minute").tag(1)
                        Text("2 minutes").tag(2)
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                    }
                }
            } header: {
                Text("Ambient Display")
            } footer: {
                Text("A full-screen clock with your music, weather, battery, and next event, "
                    + "shown while the Mac sits idle and unlocked. Any key or mouse move "
                    + "dismisses it. It can't appear on the actual lock screen — that's a "
                    + "secure space no app can draw on.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Now playing", isOn: $settings.ambientShowsNowPlaying)
                Toggle("Weather", isOn: $settings.ambientShowsWeather)
                Toggle("Battery", isOn: $settings.ambientShowsBattery)
                Toggle("Next event", isOn: $settings.ambientShowsNextEvent)
            } header: {
                Text("Show")
            } footer: {
                Text("The clock and date always show. Each card appears only when it has "
                    + "something to display.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Preview Now") {
                    ambient.showNow()
                }
            } footer: {
                Text("Shows the ambient display right away. Move the mouse or press a key to "
                    + "dismiss it.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Ambient Display")
    }
}
