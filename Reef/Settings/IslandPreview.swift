import SwiftUI

/// A live, clickable miniature of the island for the settings window.
///
/// It draws with the same surface, shape, and content as the real overlay
/// over a colorful backdrop, so material, accent, and motion choices can be
/// judged before leaving the window. Clicking it opens and closes it with the
/// selected motion.
struct IslandPreview: View {
    @EnvironmentObject private var settings: ReefSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOpen = true

    private let restingSize = CGSize(width: 200, height: 30)
    private let sample = BatterySnapshot(
        isPresent: true, percent: 76, isCharging: true, isPluggedIn: true)

    private var size: CGSize {
        isOpen ? NotchState.expandedSize(collapsed: restingSize) : winged
    }

    private var winged: CGSize {
        CGSize(width: restingSize.width + NotchState.wingWidth * 2, height: restingSize.height)
    }

    private var shape: NotchShape {
        let radius = isOpen ? ReefTheme.Radius.island : size.height / 2
        return NotchShape(topCornerRadius: radius, bottomCornerRadius: radius)
    }

    var body: some View {
        ZStack(alignment: .top) {
            PreviewBackdrop(accent: settings.accent.color)

            ZStack(alignment: .top) {
                IslandSurface(shape: shape, material: settings.material)
                    .frame(width: size.width, height: size.height)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 3)

                if isOpen {
                    IslandHomeView(
                        battery: sample,
                        accent: settings.accent.color,
                        headerHeight: restingSize.height,
                        notchWidth: 0)
                        .frame(width: size.width, height: size.height)
                        .transition(.islandContent)
                } else {
                    LiveActivityWings(
                        activity: .charging(percent: sample.percent),
                        centerWidth: restingSize.width,
                        showsLabel: true)
                        .frame(height: restingSize.height)
                        .transition(.islandContent)
                }
            }
            .padding(.top, 14)
            .environment(\.colorScheme, .dark)
            .environment(\.islandBlendingMode, .withinWindow)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { replay() }
        .overlay(alignment: .bottomTrailing) {
            Text(isOpen ? "Click to close" : "Click to open")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.35)))
                .padding(10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Island preview")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { replay() }
    }

    /// Open or close the preview with the selected motion.
    func replay() {
        let spring = isOpen ? settings.motion.close : settings.motion.open
        withAnimation(MotionStyle.animation(spring, reduceMotion: reduceMotion)) {
            isOpen.toggle()
        }
    }
}

/// A soft, colorful wallpaper stand-in so glass has something to refract.
private struct PreviewBackdrop: View {
    var accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.16, blue: 0.36),
                    Color(red: 0.36, green: 0.22, blue: 0.52),
                    Color(red: 0.95, green: 0.55, blue: 0.42),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
            Circle()
                .fill(accent)
                .frame(width: 180, height: 180)
                .blur(radius: 40)
                .offset(x: -150, y: 10)
            Circle()
                .fill(Color(red: 1.0, green: 0.82, blue: 0.4))
                .frame(width: 140, height: 140)
                .blur(radius: 36)
                .offset(x: 170, y: 60)
        }
    }
}
