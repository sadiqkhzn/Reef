import SwiftUI

/// Which live activities may spread the island's wings, with a way to preview
/// each one.
struct LiveActivitySettingsPage: View {
    @EnvironmentObject private var settings: ReefSettings
    @EnvironmentObject private var activities: LiveActivityCenter

    var body: some View {
        Form {
            Section {
                ActivityRow(
                    title: "Charging",
                    detail: "When power is connected, and when the battery is full.",
                    symbol: "bolt.fill",
                    tint: ReefTheme.Status.charging,
                    isOn: $settings.showsChargingActivity
                ) {
                    activities.present(.charging(percent: 64))
                }

                ActivityRow(
                    title: "Low battery",
                    detail: "At \(BatteryActivityPolicy.lowThreshold)% and again at "
                        + "\(BatteryActivityPolicy.criticalThreshold)% while on battery.",
                    symbol: "battery.25percent",
                    tint: ReefTheme.Status.warning,
                    isOn: $settings.showsLowBatteryActivity
                ) {
                    activities.present(
                        .lowBattery(percent: BatteryActivityPolicy.lowThreshold, isCritical: false))
                }

                ActivityRow(
                    title: "Devices",
                    detail: "When AirPods, headphones, or another Bluetooth device connects.",
                    symbol: "airpodspro",
                    tint: .white,
                    isOn: $settings.showsDeviceActivity
                ) {
                    activities.present(
                        .deviceConnected(name: "AirPods Pro", kind: .airpodsPro, battery: 82))
                }

                ActivityRow(
                    title: "Audio output",
                    detail: "When sound switches to wired headphones, HDMI, USB, or AirPlay.",
                    symbol: "headphones",
                    tint: .white,
                    isOn: $settings.showsAudioOutputActivity
                ) {
                    activities.present(.audioOutput(name: "External Headphones", kind: .headphones))
                }

                ActivityRow(
                    title: "Calendar",
                    detail: "A heads-up \(settings.calendarLeadMinutes) minutes before an event starts.",
                    symbol: "calendar",
                    tint: .white,
                    isOn: $settings.showsCalendarActivity
                ) {
                    activities.present(.calendarEvent(title: "Design Review", countdown: "in 10 min"))
                }

                if settings.showsCalendarActivity {
                    Picker("Remind me", selection: $settings.calendarLeadMinutes) {
                        Text("1 minute before").tag(1)
                        Text("5 minutes before").tag(5)
                        Text("10 minutes before").tag(10)
                        Text("15 minutes before").tag(15)
                        Text("30 minutes before").tag(30)
                    }
                }

                Toggle("Show next event on the island", isOn: $settings.showsEventAtRest)
            } header: {
                Text("Activities")
            } footer: {
                Text("Live activities show briefly beside the notch without opening Reef, "
                    + "with a line of detail underneath for the first two seconds. "
                    + "Media, timers, downloads, and more join this list as they arrive.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Live Activities")
    }
}

private struct ActivityRow: View {
    var title: String
    var detail: String
    var symbol: String
    var tint: Color
    @Binding var isOn: Bool
    var preview: () -> Void

    var body: some View {
        HStack(spacing: ReefTheme.Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.black.opacity(0.85)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Preview", action: preview)
                .controlSize(.small)
                .disabled(!isOn)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}
