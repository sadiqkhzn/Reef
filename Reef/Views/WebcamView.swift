import AVFoundation
import SwiftUI

/// The mirror pane: a full-bleed front-camera preview with a small floating HUD
/// for flip and freeze. The session runs only while this pane is visible.
struct WebcamView: View {
    @ObservedObject var model: WebcamModel
    var accent: Color
    var headerHeight: CGFloat
    var notchWidth: CGFloat
    /// Leave the open island (back to home).
    var onClose: () -> Void

    private var topInset: CGFloat {
        notchWidth > 0 ? headerHeight : ReefTheme.Spacing.s
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)
            viewport
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: ReefTheme.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ReefTheme.Radius.card, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1))
                .padding(.horizontal, ReefTheme.Spacing.s)
                .padding(.bottom, 12)
        }
        .onAppear(perform: model.start)
        .onDisappear(perform: model.stop)
    }

    @ViewBuilder
    private var viewport: some View {
        if model.authorized {
            ZStack(alignment: .bottomTrailing) {
                CameraPreview(session: model.session, mirrored: model.mirrored)
                hud
                    .padding(8)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "video.slash")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(ReefTheme.Ink.secondary)
                Text(model.denied ? "Camera access denied" : "Camera needs permission")
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(ReefTheme.Ink.secondary)
                if model.denied {
                    Button("Open Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.22))
        }
    }

    private var hud: some View {
        HStack(spacing: ReefTheme.Spacing.s) {
            hudButton(model.mirrored ? "arrow.left.and.right" : "person.fill") {
                model.mirrored.toggle()
            }
            hudButton(model.frozen ? "play.fill" : "snowflake") {
                model.toggleFreeze()
            }
        }
        .padding(.horizontal, ReefTheme.Spacing.s)
        .padding(.vertical, 5)
        .background(Capsule().fill(.black.opacity(0.45)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
    }

    private func hudButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
