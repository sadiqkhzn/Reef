import SwiftUI
import UniformTypeIdentifiers

/// Material, accent color, and motion, with a live preview at the top.
struct AppearanceSettingsPage: View {
    @EnvironmentObject private var settings: ReefSettings

    @State private var showingBrandImporter = false

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
                Toggle("Celebrate a full charge", isOn: $settings.particleEffects)
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
                Toggle("Synced lyrics", isOn: $settings.showsLyrics)
            } header: {
                Text("Now Playing")
            } footer: {
                Text(settings.playerTint.summary
                    + " Source picks which player the island follows. Live waveform moves "
                    + "the equalizer with the real audio, and asks to record system audio. "
                    + "Synced lyrics are fetched from LRCLIB when a match is found.")
                    .foregroundStyle(.secondary)
            }

            brandSection
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
        .fileImporter(
            isPresented: $showingBrandImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                settings.importBrandImage(from: url)
            }
        }
    }

    @ViewBuilder
    private var brandSection: some View {
        Section {
            if let image = settings.brandImage {
                HStack(spacing: 12) {
                    BrandSwatch(image: image, tinted: settings.brandImageTinted)
                    Spacer()
                    Button("Replace…") { showingBrandImporter = true }
                    Button("Remove", role: .destructive) { settings.clearBrandImage() }
                }
                Toggle("Show in the resting island", isOn: $settings.brandImageEnabled)
                Picker("Size", selection: $settings.brandImageSize) {
                    ForEach(BrandImageSize.allCases) { Text($0.title).tag($0) }
                }
                HStack {
                    Text("Opacity")
                    Slider(value: $settings.brandImageOpacity, in: 0.3...1)
                    Text("\(Int(settings.brandImageOpacity * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                Toggle("Tint to match the theme", isOn: $settings.brandImageTinted)
            } else {
                Button {
                    showingBrandImporter = true
                } label: {
                    Label("Choose Image…", systemImage: "photo.badge.plus")
                }
            }
        } header: {
            Text("Brand Image")
        } footer: {
            Text("Shown in the resting island when nothing else is there. On a notched Mac it sits beside the notch; otherwise it's centered. Use a transparent PNG wordmark designed to read at about 24pt tall (export @3×, long edge ≤ 512px).")
                .foregroundStyle(.secondary)
        }
    }
}

/// A small dark swatch that previews the brand image the way the island draws it.
private struct BrandSwatch: View {
    let image: NSImage
    let tinted: Bool

    var body: some View {
        Image(nsImage: image)
            .renderingMode(tinted ? .template : .original)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(height: 22)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .frame(minWidth: 80)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
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
