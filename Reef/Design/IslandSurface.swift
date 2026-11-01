import AppKit
import SwiftUI

/// The body of the island: its material, the band that hides the hardware
/// notch, and the rim of light along its edge.
///
/// Content is drawn on top of this view by the caller. Nothing inside the
/// island is glass itself; cards use plain translucent fills, because glass
/// cannot sample other glass and stacking it muddies the result.
///
/// Accessibility settings are honored here so every surface gets them for
/// free: Reduce Transparency draws the solid material, and Increase Contrast
/// swaps the soft rim for a clear, solid edge.
struct IslandSurface: View {
    var shape: NotchShape
    var material: IslandMaterial
    /// Height of a solid band kept along the top so the hardware notch stays
    /// hidden behind the island. Zero when there is no notch to hide.
    var notchBand: CGFloat = 0
    /// Brightens the rim while the pointer is over the island.
    var isHighlighted: Bool = false
    /// Draws a clear, solid edge for legibility, as the system Increase Contrast
    /// setting does, but on request.
    var contrastOutline: Bool = false
    /// Adds a soft, graduated backdrop blur that intensifies toward the bottom
    /// edge, so the island melts into what's behind it.
    var progressiveBlur: Bool = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var resolved: IslandMaterial {
        material.resolved(
            liquidGlassAvailable: IslandMaterial.isLiquidGlassAvailable,
            reduceTransparency: reduceTransparency)
    }

    var body: some View {
        ZStack {
            fill
            if progressiveBlur && resolved != .midnight {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.9)],
                            startPoint: .top, endPoint: .bottom))
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) { band }
        .clipShape(shape)
        .overlay(rim)
    }

    // MARK: - Fill

    @ViewBuilder
    private var fill: some View {
        switch resolved {
        case .midnight:
            ZStack {
                Color.black
                Sheen(strength: 0.06)
            }
        case .frosted:
            FrostedFill()
        case .liquid:
            LiquidGlassFill(shape: shape)
        }
    }

    // MARK: - Notch band

    /// A solid top band that fades into the material below it, so on a notched
    /// display the resting island stays pure black over the cutout and the
    /// glass only shows once the island grows past the notch.
    @ViewBuilder
    private var band: some View {
        if notchBand > 0 && resolved != .midnight {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.7),
                    .init(color: .black.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom)
            .frame(height: notchBand + 12)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Rim

    @ViewBuilder
    private var rim: some View {
        if contrast == .increased || contrastOutline {
            shape.stroke(Color.white.opacity(0.6), lineWidth: 1)
        } else {
            switch resolved {
            case .midnight:
                shape.stroke(Color.white.opacity(isHighlighted ? 0.14 : 0.08), lineWidth: 0.5)
            case .frosted:
                shape.stroke(specularRim, lineWidth: 1)
            case .liquid:
                // The system glass draws its own edge light; only a faint
                // hairline is added so the shape holds on very dark wallpapers.
                shape.stroke(Color.white.opacity(isHighlighted ? 0.16 : 0.07), lineWidth: 0.5)
            }
        }
    }

    /// Light catching the top-leading edge and, more faintly, the bottom
    /// trailing edge, as if lit from above.
    private var specularRim: LinearGradient {
        let strength = isHighlighted ? 1.0 : 0.7
        return LinearGradient(
            colors: [
                .white.opacity(0.42 * strength),
                .white.opacity(0.10 * strength),
                .white.opacity(0.04 * strength),
                .white.opacity(0.20 * strength),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
    }
}

/// A soft top-down highlight so a surface is not perfectly flat.
private struct Sheen: View {
    var strength: Double

    var body: some View {
        LinearGradient(
            colors: [Color.white.opacity(strength), Color.clear],
            startPoint: .top,
            endPoint: .center)
    }
}

/// Frosted glass: the desktop behind the island, blurred and darkened enough
/// that white text stays readable over any wallpaper.
private struct FrostedFill: View {
    @Environment(\.islandBlendingMode) private var blendingMode

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: blendingMode)
            Color.black.opacity(0.5)
            Sheen(strength: 0.12)
        }
    }
}

/// The system Liquid Glass material, tinted dark for legibility. Builds made
/// with an older SDK, and older systems, draw frosted glass instead.
private struct LiquidGlassFill: View {
    var shape: NotchShape

    var body: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(Color.black.opacity(0.45)), in: shape)
        } else {
            FrostedFill()
        }
        #else
        FrostedFill()
        #endif
    }
}

private struct IslandBlendingModeKey: EnvironmentKey {
    static let defaultValue: NSVisualEffectView.BlendingMode = .behindWindow
}

extension EnvironmentValues {
    /// What frosted glass blurs. The overlay blurs the desktop behind its
    /// window; previews inside the settings window blur their own backdrop.
    var islandBlendingMode: NSVisualEffectView.BlendingMode {
        get { self[IslandBlendingModeKey.self] }
        set { self[IslandBlendingModeKey.self] = newValue }
    }
}
