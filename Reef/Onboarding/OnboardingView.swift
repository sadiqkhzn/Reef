import SwiftUI

/// The first-run welcome and permissions screen.
struct OnboardingView: View {
    @ObservedObject var permissions: PermissionsModel
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Image(systemName: "water.waves")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Welcome to Reef")
                    .font(.title.weight(.semibold))
                Text("A quiet widget for the notch: now playing, battery, your next event, the weather, and a shelf for files.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                PermissionCard(
                    icon: "calendar",
                    title: "Calendar",
                    detail: "Show your next event and a reminder before it starts.",
                    status: permissions.calendar,
                    onAllow: permissions.requestCalendar,
                    onOpenSettings: permissions.openCalendarSettings)

                PermissionCard(
                    icon: "location.fill",
                    title: "Location",
                    detail: "Show local weather for where you are.",
                    status: permissions.location,
                    onAllow: permissions.requestLocation,
                    onOpenSettings: permissions.openLocationSettings)

                PermissionCard(
                    icon: "dot.radiowaves.left.and.right",
                    title: "Bluetooth",
                    detail: "Show AirPods and other device battery, and connect activity.",
                    status: permissions.bluetooth,
                    onAllow: permissions.requestBluetooth,
                    onOpenSettings: permissions.openBluetoothSettings)
            }

            Text("Both are optional. Reef works without them, and you can change your mind in System Settings anytime.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            Button(action: onDone) {
                Text("Get Started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(28)
        .frame(width: 440, height: 560)
        .onAppear { permissions.refresh() }
    }
}

/// One permission row with a status-dependent action.
private struct PermissionCard: View {
    let icon: String
    let title: String
    let detail: String
    let status: PermissionStatus
    var onAllow: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            control
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05)))
    }

    @ViewBuilder
    private var control: some View {
        switch status {
        case .notDetermined:
            Button("Allow", action: onAllow)
                .buttonStyle(.bordered)
        case .denied:
            Button("Settings", action: onOpenSettings)
                .buttonStyle(.bordered)
        case .granted:
            Label("Allowed", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.subheadline)
                .foregroundStyle(.green)
        }
    }
}
