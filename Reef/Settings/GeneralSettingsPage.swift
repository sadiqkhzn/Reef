import ServiceManagement
import SwiftUI

/// Where the island sits and whether Reef starts at login.
struct GeneralSettingsPage: View {
    @EnvironmentObject private var settings: ReefSettings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Picker("Style", selection: $settings.overlayStyle) {
                    ForEach(OverlayStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Island")
            } footer: {
                Text("Attached hugs the top edge and flows out of the notch. "
                    + "Floating sits just below the top edge as its own rounded bubble.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Open Reef at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                if let loginError {
                    Text(loginError)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Startup")
            }

            Section {
                Toggle("Open on hover", isOn: $settings.opensOnHover)
                if settings.opensOnHover {
                    Picker("After", selection: $settings.hoverOpenSeconds) {
                        Text("0.5 seconds").tag(0.5)
                        Text("1 second").tag(1.0)
                        Text("2 seconds").tag(2.0)
                        Text("3 seconds").tag(3.0)
                    }
                }
                Toggle("Quick peek on hover", isOn: $settings.quickPeek)
            } header: {
                Text("Opening")
            } footer: {
                Text("A click always opens the island at once. Open on hover also opens it "
                    + "after the pointer dwells. Quick peek grows it a touch the moment the "
                    + "pointer arrives.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Show local weather", isOn: $settings.showsWeather)
                if settings.showsWeather {
                    Picker("Units", selection: $settings.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Weather")
            } footer: {
                Text("Shown on the open island's home page. Reef uses your approximate "
                    + "location to fetch the forecast from Open-Meteo.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Swipe the island", isOn: $settings.swipeGesturesEnabled)
                if settings.swipeGesturesEnabled {
                    Toggle("Natural swipe direction", isOn: $settings.naturalSwipeDirection)
                }
            } header: {
                Text("Gestures")
            } footer: {
                Text("Swipe sideways on the island to skip tracks, and up or down to "
                    + "close or open it. With natural direction on, swiping left moves to "
                    + "the next track.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Restore Defaults", role: .destructive) {
                    settings.reset()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        // Reverting the toggle after a failure lands here again; there is
        // nothing to do when the system already matches.
        guard enabled != (SMAppService.mainApp.status == .enabled) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = "macOS did not accept the change: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
