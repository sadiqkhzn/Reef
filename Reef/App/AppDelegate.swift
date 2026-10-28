import AppKit
import SwiftUI

/// Sets the app up at launch.
///
/// Reef has no main window. The delegate builds the overlay, the live activity
/// center, and a menu bar item, then gets out of the way. Running as an
/// accessory keeps the app out of the Dock and the app switcher.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = ReefSettings()
    private let state = NotchState()
    private var battery: BatteryModel?
    private var activities: LiveActivityCenter?
    private var bluetooth: BluetoothMonitor?
    private var controller: NotchWindowController?
    private var settingsWindow: SettingsWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let battery = BatteryModel()
        let activities = LiveActivityCenter(state: state, settings: settings, battery: battery)
        self.battery = battery
        self.activities = activities

        startBluetooth(activities: activities)

        let controller = NotchWindowController(state: state, settings: settings, battery: battery)
        controller.show()
        self.controller = controller

        settingsWindow = SettingsWindowController { [settings] in
            SettingsView()
                .environmentObject(settings)
                .environmentObject(activities)
        }

        installMenuBarItem()
    }

    /// True when the app is only hosting the unit tests.
    private var isHostingTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Watch for Bluetooth devices connecting. Registering can wait on the
    /// Bluetooth permission check, so it runs after launch has finished, and
    /// it is skipped entirely when hosting tests, where nobody can answer the
    /// permission prompt.
    private func startBluetooth(activities: LiveActivityCenter) {
        guard !isHostingTests else { return }
        Task { @MainActor [weak self, weak activities] in
            let bluetooth = BluetoothMonitor()
            bluetooth.onConnect = { name in
                activities?.deviceConnected(named: name)
            }
            bluetooth.start()
            self?.bluetooth = bluetooth
        }
    }

    private func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "water.waves",
            accessibilityDescription: "Reef")

        let menu = NSMenu()

        let settingsItem = menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ",")
        settingsItem.target = self

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

    @objc private func openSettings() {
        settingsWindow?.show()
    }

    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
