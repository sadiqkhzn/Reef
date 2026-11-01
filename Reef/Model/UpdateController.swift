import Sparkle
import SwiftUI

/// Thin wrapper around Sparkle's standard updater, exposing just what the UI
/// needs: a way to check for updates now and a toggle for automatic checks.
///
/// The feed URL (`SUFeedURL`) and the update signing key (`SUPublicEDKey`) are
/// set in Info.plist. Until a release is published with a matching appcast and
/// signature, checking simply reports that no update is available — see
/// RELEASING.md for the release setup.
@MainActor
final class UpdateController: ObservableObject {
    private let updaterController: SPUStandardUpdaterController

    /// Whether Sparkle checks for updates on its own schedule.
    @Published var automaticallyChecks: Bool {
        didSet {
            updaterController.updater.automaticallyChecksForUpdates = automaticallyChecks
        }
    }

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        automaticallyChecks = updaterController.updater.automaticallyChecksForUpdates
    }

    /// Check now and show Sparkle's standard UI for the result.
    func checkForUpdates() {
        updaterController.updater.checkForUpdates()
    }

    /// False while a check is already in flight, so the button can disable.
    var canCheck: Bool {
        updaterController.updater.canCheckForUpdates
    }

    /// The app's marketing version, for display.
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
