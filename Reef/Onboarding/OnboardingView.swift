import SwiftUI

/// The first-run welcome and permissions flow.
///
/// One screen at a time: a welcome, then a card per permission with a preview
/// tile, a single plain-language ask, a row of the things it powers, and a
/// Continue button that fires the system prompt. It ends on a done screen.
struct OnboardingView: View {
    @ObservedObject var permissions: PermissionsModel
    var onDone: () -> Void

    @State private var step = 0

    /// Deep indigo through violet, the flow's own color, independent of the
    /// person's island accent.
    private let accent = Color(red: 0.46, green: 0.42, blue: 0.96)

    private var steps: [Step] { Step.all }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                card
                Spacer(minLength: 0)
                footer
            }
            .padding(24)
        }
        .frame(width: 460, height: 600)
        .onAppear { permissions.refresh() }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.08, green: 0.08, blue: 0.11), Color(red: 0.04, green: 0.04, blue: 0.06)],
            startPoint: .top,
            endPoint: .bottom)
            .ignoresSafeArea()
    }

    // MARK: - Card

    @ViewBuilder
    private var card: some View {
        let current = steps[step]
        Group {
            if step == 0 {
                welcomeCard
            } else if current.isShowcase {
                showcaseCard(current)
            } else if current.permission == nil {
                doneCard(current)
            } else {
                permissionCard(current)
            }
        }
        .id(step)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(x: 24)),
            removal: .opacity.combined(with: .offset(x: -24))))
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Welcome

    private var welcomeCard: some View {
        VStack(spacing: 18) {
            appTile
            VStack(spacing: 8) {
                Text("Reef")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("A quiet widget for your notch. Now playing, battery, your next event, the weather, timers, and a shelf for files.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 340)
            }
            gesturesCard
        }
    }

    /// A gradient app-icon tile with a soft glow, standing in for the Reef mark.
    private var appTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [accent, Color(red: 0.72, green: 0.33, blue: 0.93)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 92, height: 92)
                .shadow(color: accent.opacity(0.6), radius: 18, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1))
            Image(systemName: "water.waves")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    /// The three island gestures, on the glowing sub-card.
    private var gesturesCard: some View {
        HStack(spacing: 6) {
            gesture("hand.draw.fill", "Swipe sideways\nto skip tracks")
            gesture("hand.point.up.left.fill", "Swipe up or down\nto open & close")
            gesture("hand.tap.fill", "Tap to open\nthe island")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(glowCardBackground)
    }

    private func gesture(_ symbol: String, _ label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Showcase

    private func showcaseCard(_ current: Step) -> some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(
                        colors: [accent, Color(red: 0.72, green: 0.33, blue: 0.93)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .shadow(color: accent.opacity(0.55), radius: 16, y: 5)
                Image(systemName: current.heroSymbol)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(current.title)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
            if !current.items.isEmpty {
                iconRow(current.items)
            }
            Text(current.caption)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
        }
    }

    // MARK: - Permission

    private func permissionCard(_ current: Step) -> some View {
        VStack(spacing: 20) {
            hero(current)
            Text(current.title)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)

            if !current.items.isEmpty {
                iconRow(current.items)
            }

            if let permission = current.permission {
                statusLine(for: permission)
            }
        }
    }

    // MARK: - Done

    private func doneCard(_ current: Step) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(ReefTheme.Status.charging.opacity(0.18))
                    .frame(width: 92, height: 92)
                Image(systemName: current.heroSymbol)
                    .font(.system(size: 44, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(ReefTheme.Status.charging)
            }
            Text(current.title)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(current.caption)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
        }
    }

    /// The glowing sub-card background shared by the gestures and icon rows.
    private var glowCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.04))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [.clear, Color(red: 0.7, green: 0.3, blue: 0.9).opacity(0.28)],
                    startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
    }

    /// The preview tile at the top: a rounded card holding the step's glyph and
    /// two placeholder lines, echoing a system permission sheet.
    private func hero(_ step: Step) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(
                            colors: [accent, accent.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                        .shadow(color: accent.opacity(0.5), radius: 10, y: 3)
                    Image(systemName: step.heroSymbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
                heroPreview(step.permission)
            }
        }
        .frame(width: 200, height: 156)
    }

    /// A small live-looking chip under the hero icon, showing what the island
    /// will carry once this permission is on.
    @ViewBuilder
    private func heroPreview(_ permission: PermissionsModel.Permission?) -> some View {
        Group {
            switch permission {
            case .calendar:
                HStack(spacing: 6) {
                    Circle().fill(Color(red: 1.0, green: 0.42, blue: 0.4)).frame(width: 6, height: 6)
                    Text("Standup").foregroundStyle(.white)
                    Text("9:30").foregroundStyle(.white.opacity(0.55))
                }
            case .location:
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill").symbolRenderingMode(.multicolor)
                    Text("24°").foregroundStyle(.white)
                    Text("Clear").foregroundStyle(.white.opacity(0.55))
                }
            case .bluetooth:
                HStack(spacing: 6) {
                    Image(systemName: "airpodspro").foregroundStyle(.white)
                    Text("AirPods").foregroundStyle(.white)
                    Text("82%").foregroundStyle(ReefTheme.Status.charging)
                }
            case nil:
                EmptyView()
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.45)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
    }

    /// A row of the things this step powers, on a glowing sub-card.
    private func iconRow(_ items: [Step.Item]) -> some View {
        HStack(spacing: 12) {
            ForEach(items) { item in
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(
                                colors: [.white.opacity(0.14), .white.opacity(0.04)],
                                startPoint: .top, endPoint: .bottom))
                            .frame(width: 46, height: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                        Image(systemName: item.symbol)
                            .font(.system(size: item.large ? 22 : 18, weight: .regular))
                            .symbolRenderingMode(item.multicolor ? .multicolor : .hierarchical)
                            .foregroundStyle(.white)
                    }
                    Text(item.label)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(glowCardBackground)
    }

    private func statusLine(for permission: PermissionsModel.Permission) -> some View {
        let status = permissions.status(permission)
        return Group {
            switch status {
            case .granted:
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(ReefTheme.Status.charging)
            case .denied:
                Button("Open System Settings") { permissions.openSettings(permission) }
                    .buttonStyle(.plain)
                    .foregroundStyle(accent)
            case .notDetermined:
                Text("Choose Allow when macOS asks.")
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            progressDots
            Button(action: primaryAction) {
                Text(primaryTitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        Capsule().fill(LinearGradient(
                            colors: [accent, accent.opacity(0.82)],
                            startPoint: .leading, endPoint: .trailing)))
            }
            .buttonStyle(.plain)

            if steps[step].permission != nil {
                Button("Skip for now") { advance() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                Color.clear.frame(height: 16)
            }
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { index in
                Circle()
                    .fill(index == step ? accent : .white.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.bottom, 4)
    }

    private var primaryTitle: String {
        if step == 0 { return "Get Started" }
        if step == steps.count - 1 { return "Done" }
        return "Continue"
    }

    private func primaryAction() {
        let current = steps[step]
        if let permission = current.permission,
            permissions.status(permission) == .notDetermined {
            permissions.request(permission)
        }
        if step == steps.count - 1 {
            onDone()
        } else {
            advance()
        }
    }

    private func advance() {
        guard step < steps.count - 1 else { onDone(); return }
        withAnimation { step += 1 }
    }
}

/// One screen of the onboarding flow.
private struct Step {
    struct Item: Identifiable {
        let symbol: String
        let label: String
        var multicolor = false
        var large = false
        var id: String { symbol + label }
    }

    var heroSymbol: String
    var title: String
    var caption: String = ""
    var permission: PermissionsModel.Permission?
    var items: [Item] = []
    var isShowcase = false

    static let all: [Step] = [
        Step(
            heroSymbol: "water.waves",
            title: "Welcome to Reef",
            caption: "A quiet widget for the notch: now playing, battery, your next event, the weather, timers, and a shelf for files.",
            permission: nil),
        Step(
            heroSymbol: "play.circle.fill",
            title: "Reef shows whatever's playing.",
            caption: "Album art and controls appear in the notch for any source, with no extra setup.",
            permission: nil,
            items: [
                .init(symbol: "music.note", label: "Music"),
                .init(symbol: "globe", label: "Browsers"),
                .init(symbol: "waveform", label: "Any app"),
            ],
            isShowcase: true),
        Step(
            heroSymbol: "calendar",
            title: "Reef needs your permission to show your upcoming events.",
            permission: .calendar,
            items: [
                .init(symbol: "calendar", label: "Next event"),
                .init(symbol: "calendar.day.timeline.left", label: "Month"),
                .init(symbol: "bell.badge", label: "Reminders"),
            ]),
        Step(
            heroSymbol: "location.fill",
            title: "Reef needs your location to show local weather.",
            permission: .location,
            items: [
                .init(symbol: "sun.max.fill", label: "Now", multicolor: true),
                .init(symbol: "cloud.sun.fill", label: "Hourly", multicolor: true),
                .init(symbol: "cloud.rain.fill", label: "Days", multicolor: true),
            ]),
        Step(
            heroSymbol: "dot.radiowaves.left.and.right",
            title: "Reef needs your permission to show connected devices.",
            permission: .bluetooth,
            items: [
                .init(symbol: "airpods", label: "AirPods", large: true),
                .init(symbol: "airpodspro", label: "AirPods Pro", large: true),
                .init(symbol: "airpodsmax", label: "AirPods Max", large: true),
            ]),
        Step(
            heroSymbol: "checkmark.seal.fill",
            title: "You're all set.",
            caption: "Reef lives in the notch. Tap it to open, and find Settings in the menu bar anytime.",
            permission: nil),
    ]
}
