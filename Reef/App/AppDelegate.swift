import AppKit
import Combine
import IOKit
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
    private var audioOutput: AudioOutputMonitor?
    private let calendar = CalendarMonitor()
    private let weather = WeatherProvider()
    private let shelf = ShelfModel()
    private var controller: NotchWindowController?
    private var settingsWindow: SettingsWindowController?
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // During unit tests the app is only a host for the test bundle. Skip the
        // live overlay so nothing touches the screen or the music apps.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }

        NSApp.setActivationPolicy(.accessory)

        let battery = BatteryModel()
        let activities = LiveActivityCenter(
            state: state, settings: settings, battery: battery, calendar: calendar)
        self.battery = battery
        self.activities = activities

        startBluetooth(activities: activities)
        startAudioOutput(activities: activities)
        calendar.start()
        startWeather()

        let controller = NotchWindowController(
            state: state, settings: settings, battery: battery,
            calendar: calendar, weather: weather, shelf: shelf)
        controller.show()
        self.controller = controller

        settingsWindow = SettingsWindowController { [settings, calendar, weather] in
            SettingsView()
                .environmentObject(settings)
                .environmentObject(activities)
                .environmentObject(calendar)
                .environmentObject(weather)
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
            bluetooth.onDisconnect = { name in
                activities?.deviceDisconnected(named: name)
            }
            bluetooth.start()
            self?.bluetooth = bluetooth
        }
    }

    /// Start local weather, and keep it in step with the unit and the on/off
    /// setting. Skipped while hosting tests so nothing asks for location.
    private func startWeather() {
        guard !isHostingTests else { return }
        weather.unit = settings.temperatureUnit
        if settings.showsWeather { weather.start() }

        settings.$temperatureUnit
            .dropFirst()
            .sink { [weak self] unit in self?.weather.unit = unit }
            .store(in: &cancellables)

        settings.$showsWeather
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] enabled in
                if enabled { self?.weather.start() } else { self?.weather.stop() }
            }
            .store(in: &cancellables)
    }

    /// Watch for the system audio output route changing (wired headphones, HDMI,
    /// USB, AirPlay). Skipped while hosting tests.
    private func startAudioOutput(activities: LiveActivityCenter) {
        guard !isHostingTests else { return }
        let monitor = AudioOutputMonitor()
        monitor.onChange = { [weak activities] output in
            activities?.audioOutputChanged(output)
        }
        monitor.start()
        audioOutput = monitor
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

        let copyUUID = menu.addItem(
            withTitle: "Copy Hardware UUID",
            action: #selector(copyHardwareUUID),
            keyEquivalent: "")
        copyUUID.target = self

        let feedback = menu.addItem(
            withTitle: "Send Feedback…",
            action: #selector(sendFeedback),
            keyEquivalent: "")
        feedback.target = self

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

    /// Copy the Mac's hardware UUID, handy when reporting an issue.
    @objc private func copyHardwareUUID() {
        guard let uuid = Self.hardwareUUID() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(uuid, forType: .string)
    }

    @objc private func sendFeedback() {
        if let url = URL(string: "https://github.com/sadiqkhzn/Reef/issues") {
            NSWorkspace.shared.open(url)
        }
    }

    /// The Mac's hardware UUID from the IO registry.
    private static func hardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        return IORegistryEntryCreateCFProperty(
            service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
    }
}
