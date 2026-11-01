import SwiftUI

/// The battery page of the open island: a large ring with the charge, the power
/// state, and a time-left estimate when the system has one.
struct BatteryDetailView: View {
    var snapshot: BatterySnapshot
    var accent: Color
    var headerHeight: CGFloat
    var notchWidth: CGFloat
    /// How connected devices are drawn (3D models or symbols).
    var deviceArtwork: DeviceArtwork = .symbols
    /// Leave the open island (back to home).
    var onClose: () -> Void

    /// Connected Bluetooth devices that report a battery level.
    @State private var devices: [DeviceBattery] = []

    private var tint: Color {
        if snapshot.isCharging || snapshot.isPluggedIn { return ReefTheme.Status.charging }
        switch snapshot.percent {
        case ...BatteryActivityPolicy.criticalThreshold: return ReefTheme.Status.critical
        case ...BatteryActivityPolicy.lowThreshold: return ReefTheme.Status.warning
        default: return accent
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.32), tint.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header
                    .frame(height: headerHeight)
                content
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("Battery")
                .font(ReefTheme.Typography.caption)
                .foregroundStyle(accent)
                .padding(.horizontal, ReefTheme.Spacing.s)
                .padding(.vertical, 3)
                .background(Capsule().fill(accent.opacity(0.18)))
            Spacer(minLength: notchWidth + ReefTheme.Spacing.l)
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
    }

    private var content: some View {
        VStack(spacing: ReefTheme.Spacing.s) {
            macCard
            if !devices.isEmpty {
                devicesCard
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ReefTheme.Radius.islandInset)
        .padding(.bottom, ReefTheme.Radius.islandInset)
        .onAppear(perform: refreshDevices)
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            refreshDevices()
        }
    }

    private func refreshDevices() {
        devices = BluetoothBatteryReader.all()
    }

    private var macCard: some View {
        HStack(spacing: ReefTheme.Spacing.l) {
            ring
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.status.title)
                    .font(ReefTheme.Typography.title)
                    .foregroundStyle(ReefTheme.Ink.primary)
                if let estimate = snapshot.timeEstimateText {
                    Label(
                        snapshot.status == .charging
                            ? "\(estimate) to full"
                            : "\(estimate) left",
                        systemImage: snapshot.status == .charging ? "bolt.fill" : "clock")
                        .labelStyle(.titleAndIcon)
                        .font(ReefTheme.Typography.caption)
                        .foregroundStyle(ReefTheme.Ink.secondary)
                } else {
                    Text(powerSourceText)
                        .font(ReefTheme.Typography.caption)
                        .foregroundStyle(ReefTheme.Ink.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .islandCard(padding: ReefTheme.Spacing.l)
    }

    private var devicesCard: some View {
        VStack(spacing: ReefTheme.Spacing.s) {
            ForEach(devices, id: \.name) { device in
                deviceRow(device)
            }
        }
        .islandCard(padding: ReefTheme.Spacing.m)
    }

    private func deviceRow(_ device: DeviceBattery) -> some View {
        HStack(spacing: ReefTheme.Spacing.m) {
            DeviceGlyph(
                model: DeviceModel(kind: device.kind),
                symbol: device.kind.symbol,
                artwork: deviceArtwork,
                size: 24,
                symbolSize: 14,
                tint: ReefTheme.Ink.primary)
                .frame(width: 26, height: 26)

            Text(device.name)
                .font(ReefTheme.Typography.caption)
                .foregroundStyle(ReefTheme.Ink.primary)
                .lineLimit(1)

            Spacer(minLength: ReefTheme.Spacing.s)

            if let percent = device.overall {
                Text("\(percent)%")
                    .font(ReefTheme.Typography.caption.monospacedDigit())
                    .foregroundStyle(deviceTint(percent))
                miniBar(percent)
            }
        }
    }

    private func miniBar(_ percent: Int) -> some View {
        let fraction = CGFloat(min(100, max(0, percent))) / 100
        return ZStack(alignment: .leading) {
            Capsule().fill(ReefTheme.Ink.fill).frame(width: 30, height: 5)
            Capsule().fill(deviceTint(percent)).frame(width: 30 * fraction, height: 5)
        }
    }

    private func deviceTint(_ percent: Int) -> Color {
        switch percent {
        case ...BatteryActivityPolicy.criticalThreshold: return ReefTheme.Status.critical
        case ...BatteryActivityPolicy.lowThreshold: return ReefTheme.Status.warning
        default: return ReefTheme.Ink.secondary
        }
    }

    private var ring: some View {
        RingGauge(progress: Double(snapshot.percent) / 100, tint: tint, lineWidth: 6)
            .frame(width: 64, height: 64)
            .overlay {
                VStack(spacing: 0) {
                    if snapshot.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(tint)
                    }
                    Text("\(snapshot.percent)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ReefTheme.Ink.primary)
                }
            }
    }

    private var powerSourceText: String {
        switch snapshot.status {
        case .fullyCharged: return "On power adapter"
        case .notCharging: return "Holding charge"
        case .charging: return "Calculating time to full"
        case .onBattery: return "Calculating time left"
        }
    }
}
