import AppKit
import SwiftUI

/// Sets the app up at launch.
///
/// Reef has no main window. The delegate builds the overlay and a menu bar
/// item, then gets out of the way. Running as an accessory keeps the app out of
/// the Dock and the app switcher.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = NotchState()
    private var controller: NotchWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = NotchWindowController(state: state)
        controller.show()
        self.controller = controller

        installMenuBarItem()
    }

    private func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "water.waves",
            accessibilityDescription: "Reef")

        let menu = NSMenu()

        let about = menu.addItem(
            withTitle: "About Reef",
            action: #selector(openAbout),
            keyEquivalent: "")
        about.target = self

        menu.addItem(.separator())

        let quit = menu.addItem(
            withTitle: "Quit Reef",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        quit.target = NSApp

        item.menu = menu
        statusItem = item
    }

    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
