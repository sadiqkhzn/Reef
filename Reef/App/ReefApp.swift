import SwiftUI

/// Entry point.
///
/// The visible app is the overlay and the menu bar item, both built by the
/// app delegate. The menu bar item opens the settings window, which the
/// delegate also owns. SwiftUI still needs a scene, so an empty Settings scene
/// is declared; it has nothing to show because Reef has no app menu to open it
/// from.
@main
struct ReefApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
