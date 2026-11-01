import SwiftUI

/// Controls for replacing the system volume and brightness overlays with Reef's
/// HUD in the notch.
struct SystemHUDSettingsPage: View {
    @EnvironmentObject private var settings: ReefSettings
    @EnvironmentObject private var activities: LiveActivityCenter

    /// Whether Reef has Accessibility permission, refreshed on a slow tick so
    /// the status follows along after it is granted in System Settings.
    @State private var trusted = SystemHUDController.isTrusted
    private let tick = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    private var anyEnabled: Bool { settings.replacesVolumeHUD || settings.replacesBrightnessHUD }
    private var needsPermission: Bool { anyEnabled && !trusted }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.replacesVolumeHUD) {
                    Label("Replace volume overlay", systemImage: "speaker.wave.2.fill")
                }
                Toggle(isOn: $settings.replacesBrightnessHUD) {
                    Label("Replace brightness overlay", systemImage: "sun.max.fill")
                }
            } header: {
                Text("Replace System Overlays")
            } footer: {
                Text("When on, pressing the volume or brightness keys shows Reef's HUD in "
                    + "the notch instead of the system's. Keys for a part turned off, or that "
                    + "Reef can't act on, pass straight through to the system, so nothing is "
                    + "ever left unresponsive. Turning this off restores the system overlays.")
                    .foregroundStyle(.secondary)
            }

            if needsPermission {
                Section {
                    HStack(spacing: ReefTheme.Spacing.m) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility permission needed")
                            Text("Reef needs Accessibility access to read the volume and "
                                + "brightness keys. Until it's granted, the system overlays "
                                + "keep working.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open Settings") {
                            SystemHUDController.openAccessibilitySettings()
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section {
                Toggle(isOn: $settings.hudPlaysSound) {
                    Label("Play a click when volume changes", systemImage: "waveform")
                }
                .disabled(!settings.replacesVolumeHUD)
            } footer: {
                Text("A short feedback click each time the volume moves, like the Mac's own "
                    + "volume feedback.")
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack(spacing: ReefTheme.Spacing.m) {
                    Button("Volume") {
                        activities.presentHUD(.volume(level: 0.6, muted: false))
                    }
                    Button("Muted") {
                        activities.presentHUD(.volume(level: 0, muted: true))
                    }
                    Button("Brightness") {
                        activities.presentHUD(.brightness(level: 0.6))
                    }
                    Spacer()
                }
                .controlSize(.small)
            } header: {
                Text("Preview")
            } footer: {
                Text("See how the HUD looks in the notch. Previews work even before "
                    + "Accessibility is granted.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("System HUD")
        .onReceive(tick) { _ in trusted = SystemHUDController.isTrusted }
    }
}
