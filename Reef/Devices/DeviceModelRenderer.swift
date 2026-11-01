import AppKit
import Metal
import SceneKit

/// Loads Reef's device models and draws them as still images.
///
/// Each scene is loaded from the bundle and normalized: centered on the origin
/// and scaled so its longest side is one unit, which lets one camera frame
/// every model the same way. The model sits on a tilt node with a spin node
/// inside it, so a turntable can rotate it about its own vertical axis while
/// keeping the three-quarter tilt. Still images are cached by model and pixel
/// size, so the wings never draw the same picture twice.
@MainActor
final class DeviceModelRenderer {
    static let shared = DeviceModelRenderer()

    /// Node names in a prepared scene.
    enum Node {
        static let camera = "camera"
        static let spin = "spin"
    }

    private var scenes: [DeviceModel: SCNScene] = [:]
    private var unavailable: Set<DeviceModel> = []
    private var images: [String: NSImage] = [:]
    private lazy var renderer: SCNRenderer? = MTLCreateSystemDefaultDevice()
        .map { SCNRenderer(device: $0, options: nil) }

    /// A still image of `model`, `side` points square at `scale` pixels per
    /// point, or nil when the model cannot be loaded or drawn.
    func image(for model: DeviceModel, side: CGFloat, scale: CGFloat) -> NSImage? {
        let pixels = Int((side * scale).rounded())
        let key = "\(model.rawValue)@\(pixels)"
        if let cached = images[key] { return cached }
        guard let scene = sharedScene(for: model), let renderer else { return nil }

        renderer.scene = scene
        renderer.pointOfView = scene.rootNode.childNode(withName: Node.camera, recursively: false)
        let image = renderer.snapshot(
            atTime: 0,
            with: CGSize(width: pixels, height: pixels),
            antialiasingMode: .multisampling4X)
        image.size = CGSize(width: side, height: side)
        images[key] = image
        return image
    }

    private func sharedScene(for model: DeviceModel) -> SCNScene? {
        if let scene = scenes[model] { return scene }
        guard !unavailable.contains(model), let scene = Self.makeScene(model) else {
            unavailable.insert(model)
            return nil
        }
        scenes[model] = scene
        return scene
    }

    // MARK: - Scene

    /// Build a fresh, framed and lit scene for `model`. Each live view gets its
    /// own, so a spinning turntable never moves a cached still.
    nonisolated static func makeScene(_ model: DeviceModel, bundle: Bundle = .main) -> SCNScene? {
        guard let url = model.url(in: bundle),
              let source = try? SCNScene(url: url, options: nil) else {
            return nil
        }

        let content = SCNNode()
        for child in source.rootNode.childNodes {
            content.addChildNode(child)
        }
        let (low, high) = content.boundingBox
        let longest = max(high.x - low.x, high.y - low.y, high.z - low.z)
        guard longest > 0 else { return nil }
        let unit = 1 / longest
        content.scale = SCNVector3(unit, unit, unit)
        content.position = SCNVector3(
            -(low.x + high.x) / 2 * unit,
            -(low.y + high.y) / 2 * unit,
            -(low.z + high.z) / 2 * unit)

        // Tilt toward the camera, then turn to a three-quarter view.
        let spin = SCNNode()
        spin.name = Node.spin
        spin.eulerAngles.y = -0.55
        spin.addChildNode(content)
        let tilt = SCNNode()
        tilt.eulerAngles.x = 0.18
        tilt.addChildNode(spin)

        let scene = SCNScene()
        scene.rootNode.addChildNode(tilt)
        scene.background.contents = NSColor.clear
        scene.lightingEnvironment.contents = studioEnvironment()
        scene.lightingEnvironment.intensity = 1.1
        addCamera(to: scene)
        addLights(to: scene)
        return scene
    }

    private nonisolated static func addCamera(to scene: SCNScene) {
        let camera = SCNCamera()
        camera.fieldOfView = 28
        camera.zNear = 0.01
        camera.zFar = 100
        let node = SCNNode()
        node.name = Node.camera
        node.camera = camera
        node.position = SCNVector3(0, 0.15, 2.6)
        node.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(node)
    }

    /// A soft studio rig: a key from the upper right, a fill from the left, a
    /// rim from behind, and a little ambient so shadows never go black.
    private nonisolated static func addLights(to scene: SCNScene) {
        func directional(_ intensity: CGFloat, from position: SCNVector3) {
            let light = SCNLight()
            light.type = .directional
            light.intensity = intensity
            let node = SCNNode()
            node.light = light
            node.position = position
            node.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(node)
        }
        directional(1100, from: SCNVector3(2, 3, 3))
        directional(420, from: SCNVector3(-3, 1, 2))
        directional(700, from: SCNVector3(0, 2, -3))

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 220
        let node = SCNNode()
        node.light = ambient
        scene.rootNode.addChildNode(node)
    }

    /// A simple equirectangular studio: a bright ceiling fading to a soft grey
    /// floor, which gives the plastic its satin sheen and the aluminum
    /// something to reflect.
    private nonisolated static func studioEnvironment() -> NSImage {
        NSImage(size: NSSize(width: 256, height: 128), flipped: false) { rect in
            let gradient = NSGradient(colorsAndLocations:
                (NSColor(white: 0.98, alpha: 1), 0.0),
                (NSColor(white: 0.78, alpha: 1), 0.35),
                (NSColor(white: 0.42, alpha: 1), 0.6),
                (NSColor(white: 0.22, alpha: 1), 1.0))
            gradient?.draw(in: rect, angle: -90)
            return true
        }
    }
}
