import SceneKit
import XCTest
@testable import Reef

/// Checks the device models: which device gets which model, the artwork
/// setting, and that every bundled model loads in SceneKit.
final class DeviceModelTests: XCTestCase {

    func testEarbudsForInEarDevices() {
        XCTAssertEqual(DeviceModel(kind: .airpods), .earbuds)
        XCTAssertEqual(DeviceModel(kind: .airpodsPro), .earbuds)
    }

    func testHeadphonesForOverEarDevices() {
        XCTAssertEqual(DeviceModel(kind: .airpodsMax), .headphones)
        XCTAssertEqual(DeviceModel(kind: .headphones), .headphones)
        XCTAssertEqual(DeviceModel(kind: .beats), .headphones)
    }

    func testNoModelForOtherDevices() {
        for kind in [DeviceKind.keyboard, .mouse, .trackpad, .gameController, .other] {
            XCTAssertNil(DeviceModel(kind: kind), "\(kind) should fall back to its symbol")
        }
    }

    func testEveryModelIsBundled() {
        for model in DeviceModel.allCases {
            XCTAssertNotNil(model.url(), "\(model.rawValue).usdz is missing from the app bundle")
        }
    }

    func testEveryModelLoadsAndIsFramed() {
        for model in DeviceModel.allCases {
            guard let scene = DeviceModelRenderer.makeScene(model) else {
                XCTFail("\(model.rawValue) did not load")
                continue
            }
            var meshes = 0
            scene.rootNode.enumerateHierarchy { node, _ in
                if node.geometry != nil { meshes += 1 }
            }
            XCTAssertGreaterThan(meshes, 0, "\(model.rawValue) has no geometry")
            XCTAssertNotNil(
                scene.rootNode.childNode(withName: DeviceModelRenderer.Node.camera, recursively: false))

            // Normalized: the longest side is one unit, centered on the origin.
            let spin = scene.rootNode.childNode(
                withName: DeviceModelRenderer.Node.spin, recursively: true)
            let content = spin?.childNodes.first
            XCTAssertNotNil(content)
            if let content {
                let (low, high) = content.boundingBox
                let longest = max(high.x - low.x, high.y - low.y, high.z - low.z) * content.scale.x
                XCTAssertEqual(Double(longest), 1, accuracy: 0.01)
            }
        }
    }

    func testArtworkDefaultsToModelsAndPersists() {
        let name = "ReefTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)

        let first = ReefSettings(defaults: defaults)
        XCTAssertEqual(first.deviceArtwork, .models)
        first.deviceArtwork = .symbols
        XCTAssertEqual(ReefSettings(defaults: defaults).deviceArtwork, .symbols)

        first.reset()
        XCTAssertEqual(first.deviceArtwork, .models)
    }

    func testUnknownArtworkFallsBackToModels() {
        let name = "ReefTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaults.set("holograms", forKey: ReefSettings.Key.deviceArtwork)

        XCTAssertEqual(ReefSettings(defaults: defaults).deviceArtwork, .models)
    }
}
