import SwiftUI

/// Material, accent color, and motion, with a live preview at the top.
struct AppearanceSettingsPage: View {
    @EnvironmentObject private var settings: ReefSettings

    var body: some View {
        Form {
            Section {
                IslandPreview()
                    .listRowInsets(EdgeInsets())
            }

            Section("Material") {
                HStack(spacing: ReefTheme.Spacing.m) {
                    ForEach(IslandMaterial.allCases) { material in
                        MaterialTile(
                            material: material,
                            isSelected: settings.material == material
                        ) {
                            settings.material = material
                        }
                    }
                }
                .padding(.vertical, ReefTheme.Spacing.xs)

                if settings.material == .liquid && !IslandMaterial.isLiquidGlassAvailable {
                    Label(
                        "Liquid Glass needs macOS 26. Frosted glass is used on this Mac.",
                        systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Accent") {
                HStack(spacing: ReefTheme.Spacing.m) {
                    ForEach(AccentChoice.allCases) { accent in
                        AccentSwatch(accent: accent, isSelected: settings.accent == accent) {
                            settings.accent = accent
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, ReefTheme.Spacing.xs)
            }

            Section {
                Picker("Motion", selection: $settings.motion) {
                    ForEach(MotionStyle.allCases) { motion in
                        Text(motion.title).tag(motion)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Motion")
            } footer: {
                Text("Click the preview to see the island open and close. "
                    + "With Reduce Motion turned on in System Settings, Reef uses short fades instead.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Contrast outline", isOn: $settings.contrastOutline)
                Toggle("Progressive blur", isOn: $settings.progressiveBlur)
                Toggle("Haptic feedback", isOn: $settings.haptics)
            } header: {
                Text("Detail")
            } footer: {
                Text("Contrast outline draws a clear edge around the island. Haptic "
                    + "feedback gives a small tap on the trackpad when it opens or closes.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Player color", selection: $settings.playerTint) {
                    ForEach(PlayerTint.allCases) { tint in
                        Text(tint.title).tag(tint)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Source", selection: $settings.mediaSource) {
                    ForEach(MediaSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }

                Toggle("Hide while its app is frontmost", isOn: $settings.hidesMediaWhenSourceFrontmost)
                Toggle("Live waveform", isOn: $settings.useLiveWaveform)
                Toggle("Clean up track titles", isOn: $settings.hideMediaTitleExtras)
            } header: {
                Text("Now Playing")
            } footer: {
                Text(settings.playerTint.summary
                    + " Source picks which player the island follows. Live waveform moves "
                    + "the equalizer with the real audio, and asks to record system audio.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
    }
}

/// A selectable tile showing one island material on a small backdrop.
private struct MaterialTile: View {
    var material: IslandMaterial
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.35, blue: 0.75),
                            Color(red: 0.95, green: 0.55, blue: 0.42),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                    IslandSurface(
                        shape: NotchShape(topCornerRadius: 13, bottomCornerRadius: 13),
                        material: material)
                        .frame(width: 96, height: 26)
                }
                .frame(height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .environment(\.colorScheme, .dark)
                .environment(\.islandBlendingMode, .withinWindow)

                Text(material.title)
                    .font(.callout.weight(.semibold))
                Text(material.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(isSelected ? 0.06 : 0.0)))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                        lineWidth: isSelected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(material.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A round color swatch with a check when selected.
private struct AccentSwatch: View {
    var accent: AccentChoice
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(accent.color.gradient)
                .frame(width: 24, height: 24)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black.opacity(0.7))
                    }
                }
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                .padding(3)
                .overlay(
                    Circle().strokeBorder(
                        isSelected ? accent.color : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .help(accent.title)
        .accessibilityLabel(accent.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
