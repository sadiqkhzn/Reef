import SwiftUI
import XCTest
@testable import Reef

/// Checks appearance choices, the settings store, and settings search.
final class AppearanceTests: XCTestCase {

    // MARK: - Material resolution

    func testLiquidFallsBackToFrostedWithoutSystemSupport() {
        XCTAssertEqual(
            IslandMaterial.liquid.resolved(liquidGlassAvailable: false, reduceTransparency: false),
            .frosted)
        XCTAssertEqual(
            IslandMaterial.liquid.resolved(liquidGlassAvailable: true, reduceTransparency: false),
            .liquid)
    }

    func testReduceTransparencyAlwaysDrawsSolid() {
        for material in IslandMaterial.allCases {
            XCTAssertEqual(
                material.resolved(liquidGlassAvailable: true, reduceTransparency: true),
                .midnight)
        }
    }

    func testOtherMaterialsPassThrough() {
        XCTAssertEqual(
            IslandMaterial.frosted.resolved(liquidGlassAvailable: false, reduceTransparency: false),
            .frosted)
        XCTAssertEqual(
            IslandMaterial.midnight.resolved(liquidGlassAvailable: true, reduceTransparency: false),
            .midnight)
    }

    // MARK: - Motion

    func testSmoothNeverOvershoots() {
        let smooth = MotionStyle.smooth
        XCTAssertEqual(smooth.open.dampingFraction, 1.0, accuracy: 0.001)
        XCTAssertEqual(smooth.close.dampingFraction, 1.0, accuracy: 0.001)
    }

    func testClosingIsNeverBouncierThanOpening() {
        for motion in MotionStyle.allCases {
            XCTAssertGreaterThanOrEqual(motion.close.dampingFraction, motion.open.dampingFraction)
        }
    }

    // MARK: - Overlay style

    func testOnlyAttachedHasShoulders() {
        XCTAssertGreaterThan(OverlayStyle.attached.shoulder, 0)
        XCTAssertEqual(OverlayStyle.floating.shoulder, 0)
    }

    // MARK: - Shape

    func testFlaredShapeFillsItsRect() {
        let rect = CGRect(x: 0, y: 0, width: 212, height: 32)
        let path = NotchShape(topCornerRadius: 6, bottomCornerRadius: 13, shoulder: 6)
            .path(in: rect)

        XCTAssertEqual(path.boundingRect.minX, rect.minX, accuracy: 0.5)
        XCTAssertEqual(path.boundingRect.maxX, rect.maxX, accuracy: 0.5)
        XCTAssertEqual(path.boundingRect.height, rect.height, accuracy: 0.5)
        // The body sits inside the shoulders, so a point just below the top
        // corner is outside the shape.
        XCTAssertFalse(path.contains(CGPoint(x: 1, y: 10)))
        XCTAssertTrue(path.contains(CGPoint(x: rect.midX, y: 10)))
    }

    func testRoundedShapeFillsItsRect() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 28)
        let path = NotchShape(topCornerRadius: 14, bottomCornerRadius: 14).path(in: rect)

        XCTAssertEqual(path.boundingRect.width, rect.width, accuracy: 0.5)
        XCTAssertTrue(path.contains(CGPoint(x: 2, y: 14)))
    }

    // MARK: - Settings store

    private func freshDefaults() -> UserDefaults {
        let name = "ReefTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testSettingsStartAtDefaults() {
        let settings = ReefSettings(defaults: freshDefaults())

        XCTAssertEqual(settings.overlayStyle, ReefSettings.defaultOverlayStyle)
        XCTAssertEqual(settings.material, ReefSettings.defaultMaterial)
        XCTAssertEqual(settings.accent, ReefSettings.defaultAccent)
        XCTAssertEqual(settings.motion, ReefSettings.defaultMotion)
        XCTAssertTrue(settings.showsChargingActivity)
        XCTAssertTrue(settings.showsLowBatteryActivity)
    }

    func testSettingsPersistAcrossInstances() {
        let defaults = freshDefaults()
        let first = ReefSettings(defaults: defaults)
        first.overlayStyle = .attached
        first.material = .frosted
        first.accent = .coral
        first.motion = .bouncy
        first.showsLowBatteryActivity = false

        let second = ReefSettings(defaults: defaults)

        XCTAssertEqual(second.overlayStyle, .attached)
        XCTAssertEqual(second.material, .frosted)
        XCTAssertEqual(second.accent, .coral)
        XCTAssertEqual(second.motion, .bouncy)
        XCTAssertFalse(second.showsLowBatteryActivity)
    }

    func testUnknownStoredValueFallsBackToDefault() {
        let defaults = freshDefaults()
        defaults.set("holographic", forKey: ReefSettings.Key.material)

        let settings = ReefSettings(defaults: defaults)

        XCTAssertEqual(settings.material, ReefSettings.defaultMaterial)
    }

    func testResetRestoresDefaults() {
        let settings = ReefSettings(defaults: freshDefaults())
        settings.material = .midnight
        settings.showsChargingActivity = false

        settings.reset()

        XCTAssertEqual(settings.material, ReefSettings.defaultMaterial)
        XCTAssertTrue(settings.showsChargingActivity)
    }

    // MARK: - Settings search

    func testEmptySearchMatchesEverything() {
        XCTAssertTrue(SettingsSection.allCases.allSatisfy { $0.matches("  ") })
    }

    func testSearchMatchesTitleAndKeywords() {
        XCTAssertTrue(SettingsSection.appearance.matches("appear"))
        XCTAssertTrue(SettingsSection.appearance.matches("Glass"))
        XCTAssertTrue(SettingsSection.liveActivities.matches("battery"))
        XCTAssertFalse(SettingsSection.about.matches("glass"))
    }
}
