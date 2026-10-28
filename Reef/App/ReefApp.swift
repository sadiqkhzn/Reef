import SwiftUI

/// Entry point.
///
/// The visible app is the overlay and the menu bar item, both built by the
/// app delegate. The only SwiftUI scene is Settings, which the menu bar item
/// and the standard Cmd+comma shortcut open.
@main
struct ReefApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
