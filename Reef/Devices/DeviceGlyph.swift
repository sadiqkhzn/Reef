import SceneKit
import SwiftUI

/// A device icon: Reef's 3D model when one fits and the person chose models,
/// otherwise the device's SF Symbol.
///
/// Still by default, which is what the wings use. With `spins`, the model
/// turns slowly on a live turntable, as in the onboarding tiles; Reduce Motion
/// keeps it still.
struct DeviceGlyph: View {
    var model: DeviceModel?
    var symbol: String
    var artwork: DeviceArtwork
    /// Side of the square the model is drawn in, in points.
    var size: CGFloat
    /// Point size for the symbol fallback.
    var symbolSize: CGFloat
    var tint: Color = ReefTheme.Ink.primary
    var spins: Bool = false

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if artwork == .models, let model, model.url() != nil {
            if spins && !reduceMotion {
                DeviceModelView(model: model)
                    .frame(width: size, height: size)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            } else if let image = DeviceModelRenderer.shared.image(
                for: model, side: size, scale: displayScale) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
                    .accessibilityHidden(true)
            } else {
                symbolView
            }
        } else {
            symbolView
        }
    }

    private var symbolView: some View {
        Image(systemName: symbol)
            .font(.system(size: symbolSize, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
    }
}

/// A live SceneKit view of a device model turning slowly on a transparent
/// background.
struct DeviceModelView: NSViewRepresentable {
    var model: DeviceModel
    /// Seconds for one full turn.
    var period: TimeInterval = 14

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero, options: nil)
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        if let scene = DeviceModelRenderer.makeScene(model) {
            view.scene = scene
            view.pointOfView = scene.rootNode.childNode(
                withName: DeviceModelRenderer.Node.camera, recursively: false)
            let turn = SCNAction.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: period)
            scene.rootNode.childNode(withName: DeviceModelRenderer.Node.spin, recursively: true)?
                .runAction(.repeatForever(turn))
            view.isPlaying = true
        }
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {}
}
