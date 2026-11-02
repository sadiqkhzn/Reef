import AppKit
import SwiftUI

/// The color-picker pane: an eyedropper and recent swatches on the left, the
/// selected color's formats as copy-pills on the right.
struct ColorPickerView: View {
    @ObservedObject var model: ColorPickerModel
    var accent: Color
    var headerHeight: CGFloat
    var notchWidth: CGFloat
    /// Leave the open island (back to home).
    var onClose: () -> Void

    @State private var copied: String?

    private var topInset: CGFloat {
        notchWidth > 0 ? headerHeight : ReefTheme.Spacing.s
    }

    private var current: Color { model.selected?.color ?? accent }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)
            HStack(alignment: .top, spacing: ReefTheme.Spacing.s) {
                leftWell
                    .frame(width: 164)
                formats
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, ReefTheme.Spacing.s)
            .padding(.bottom, 12)
        }
        // A soft bleed of the current color in the top-left corner.
        .background(
            RadialGradient(
                colors: [current.opacity(0.4), .clear],
                center: .topLeading, startRadius: 0, endRadius: 200)
                .blur(radius: 24)
                .allowsHitTesting(false))
    }

    // MARK: - Left: eyedropper + swatches

    private var leftWell: some View {
        VStack(spacing: ReefTheme.Spacing.s) {
            Button(action: model.pick) {
                VStack(spacing: 6) {
                    Circle()
                        .fill(current)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: current.opacity(0.5), radius: 8)
                    Label("Pick Color", systemImage: "eyedropper")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ReefTheme.Ink.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ReefTheme.Spacing.m)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .islandCard(padding: 0)

            if !model.recents.isEmpty {
                swatches
            }
        }
    }

    private var swatches: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5),
            spacing: 6) {
            ForEach(model.recents) { swatch in
                Button { model.select(swatch) } label: {
                    Circle()
                        .fill(swatch.color)
                        .frame(height: 20)
                        .overlay(
                            Circle().strokeBorder(
                                swatch.id == model.selected?.id ? .white.opacity(0.9) : .white.opacity(0.2),
                                lineWidth: swatch.id == model.selected?.id ? 1.5 : 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(swatch.hex)
            }
        }
    }

    // MARK: - Right: format copy-pills

    private var formats: some View {
        VStack(spacing: ReefTheme.Spacing.s) {
            copyPill("HEX", model.selected?.hex)
            copyPill("RGB", model.selected?.rgb)
            copyPill("HSL", model.selected?.hsl)
            copyPill("SWIFT", model.selected?.swift)
        }
    }

    private func copyPill(_ label: String, _ value: String?) -> some View {
        Button { if let value { copy(value) } } label: {
            HStack(spacing: ReefTheme.Spacing.s) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(ReefTheme.Ink.tertiary)
                    .frame(width: 34, alignment: .leading)
                Text(value ?? "—")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(ReefTheme.Ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Image(systemName: copied == label ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(copied == label ? accent : ReefTheme.Ink.secondary)
            }
            .padding(.horizontal, ReefTheme.Spacing.m)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: ReefTheme.Radius.control, style: .continuous)
                    .fill(.white.opacity(0.05)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(value == nil)
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) { copied = labelFor(value) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.2)) { copied = nil }
        }
    }

    /// Match the copied value back to its pill label for the checkmark.
    private func labelFor(_ value: String) -> String {
        if value == model.selected?.hex { return "HEX" }
        if value == model.selected?.rgb { return "RGB" }
        if value == model.selected?.hsl { return "HSL" }
        return "SWIFT"
    }
}
