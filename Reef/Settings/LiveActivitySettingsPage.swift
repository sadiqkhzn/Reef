import SwiftUI

/// Which live activities may spread the island's wings, with a way to preview
/// each one.
struct LiveActivitySettingsPage: View {
    @EnvironmentObject private var settings: ReefSettings
    @EnvironmentObject private var activities: LiveActivityCenter
    @EnvironmentObject private var calendar: CalendarMonitor

    var body: some View {
        Form {
            Section {
                IdleActivityPicker(showsEvent: $settings.showsEventAtRest)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Idle Activity")
            } footer: {
                Text("What the resting island shows when nothing is playing. Media always "
                    + "takes over the wings while a track is on.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(isOn: $settings.batteryActivitiesEnabled) {
                    Label("Battery", systemImage: "battery.100percent")
                }

                if settings.batteryActivitiesEnabled {
                    LabeledContent("Duration") {
                        HStack {
                            Slider(value: $settings.batteryActivityDuration, in: 1...10, step: 0.5)
                                .frame(width: 150)
                            Text(String(format: "%.1f s", settings.batteryActivityDuration))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }

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
                        title: "Notify on low power mode",
                        detail: "When Low Power Mode turns on.",
                        symbol: "leaf.fill",
                        tint: ReefTheme.Status.warning,
                        isOn: $settings.showsLowPowerModeActivity
                    ) {
                        activities.present(.lowPowerMode)
                    }

                    ActivityRow(
                        title: "Warn on low battery",
                        detail: "At the chosen level and again at "
                            + "\(BatteryActivityPolicy.criticalThreshold)% while on battery.",
                        symbol: "battery.25percent",
                        tint: ReefTheme.Status.warning,
                        isOn: $settings.showsLowBatteryActivity
                    ) {
                        activities.present(
                            .lowBattery(percent: settings.lowBatteryThreshold, isCritical: false))
                    }

                    if settings.showsLowBatteryActivity {
                        LabeledContent("Low battery threshold") {
                            HStack {
                                Slider(
                                    value: Binding(
                                        get: { Double(settings.lowBatteryThreshold) },
                                        set: { settings.lowBatteryThreshold = Int($0) }),
                                    in: 10...50, step: 5)
                                    .frame(width: 150)
                                Text("\(settings.lowBatteryThreshold)%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Toggle("Play sound on low battery", isOn: $settings.lowBatterySound)
                            if settings.lowBatterySound {
                                Button {
                                    LiveActivityCenter.playLowBatterySound()
                                } label: {
                                    Image(systemName: "play.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Toggle("Hide label", isOn: $settings.hidesActivityLabel)
                    Toggle("Hide percentage", isOn: $settings.hidesBatteryPercentage)
                }
            } header: {
                Text("Battery")
            } footer: {
                Text("Battery activities show beside the notch when power connects, the "
                    + "battery runs low, or Low Power Mode turns on. Duration sets how long "
                    + "they stay. Hide label drops the center text on Macs without a notch.")
                    .foregroundStyle(.secondary)
            }

            Section {
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

            } header: {
                Text("Activities")
            } footer: {
                Text("Live activities show briefly beside the notch without opening Reef, "
                    + "with a line of detail underneath for the first two seconds. "
                    + "Media, timers, downloads, and more join this list as they arrive.")
                    .foregroundStyle(.secondary)
            }

            if !calendar.calendars.isEmpty {
                Section {
                    ForEach(calendar.calendars) { cal in
                        Toggle(isOn: calendarBinding(cal.id)) {
                            Label {
                                Text(cal.title)
                            } icon: {
                                Circle()
                                    .fill(cal.colorHex.flatMap(Color.init(hex:)) ?? .secondary)
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                } header: {
                    Text("Calendars")
                } footer: {
                    Text("Only events from the calendars turned on here show in the island.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Live Activities")
    }

    /// A toggle bound to whether a calendar is shown (on) or hidden (off).
    private func calendarBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !settings.hiddenCalendarIDs.contains(id) },
            set: { shown in
                if shown {
                    settings.hiddenCalendarIDs.remove(id)
                } else {
                    settings.hiddenCalendarIDs.insert(id)
                }
            })
    }
}

/// A pair of tiles for the resting island's idle activity: nothing, or the next
/// calendar event. Media is automatic and so is not an option here.
private struct IdleActivityPicker: View {
    @Binding var showsEvent: Bool

    var body: some View {
        HStack(spacing: ReefTheme.Spacing.m) {
            tile(title: "None", symbol: "circle.slash", selected: !showsEvent) {
                showsEvent = false
            }
            tile(title: "Next event", symbol: "calendar", selected: showsEvent) {
                showsEvent = true
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func tile(
        title: String, symbol: String, selected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .frame(height: 24)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .frame(width: 92, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(selected ? 0.08 : 0.04)))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        selected ? Color.accentColor : Color.primary.opacity(0.08),
                        lineWidth: selected ? 2 : 0.5))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
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
