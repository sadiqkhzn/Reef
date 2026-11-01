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
    private var systemHUD: SystemHUDController?
    private var media: NowPlayingController?
    private var ambient: AmbientController?
    private let calendar = CalendarMonitor()
    private let weather = WeatherProvider()
    private let shelf = ShelfModel()
    private let focus = FocusMonitor()
    private let onboarding = OnboardingWindowController()
    private let keepAwake = KeepAwakeManager()
    private var screenLock: ScreenLockMonitor?
    private var lockOverlay: LockScreenOverlayManager?
    private var keepAwakeItem: NSMenuItem?
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
        focus.start()
        let activities = LiveActivityCenter(
            state: state, settings: settings, battery: battery, calendar: calendar,
            focus: focus)
        self.battery = battery
        self.activities = activities

        startAudioOutput(activities: activities)
        startSystemHUD(activities: activities)

        // One now-playing reader, shared by the overlay and the ambient display,
        // so only a single media stream runs.
        let media = NowPlayingController()
        self.media = media

        let controller = NotchWindowController(
            state: state, settings: settings, battery: battery,
            calendar: calendar, weather: weather, shelf: shelf, media: media)
        controller.show()
        self.controller = controller

        let ambient = AmbientController(settings: settings) { [settings, media, weather, battery, calendar] in
            AnyView(
                AmbientView()
                    .environmentObject(settings)
                    .environmentObject(media)
                    .environmentObject(weather)
                    .environmentObject(battery)
                    .environmentObject(calendar))
        }
        ambient.start()
        self.ambient = ambient

        let lockState = LockScreenState()
        let lockOverlay = LockScreenOverlayManager(settings: settings, lockState: lockState) {
            [settings, media, weather, battery, calendar, state] in
            AnyView(
                LockScreenView()
                    .environmentObject(settings)
                    .environmentObject(media)
                    .environmentObject(weather)
                    .environmentObject(battery)
                    .environmentObject(calendar)
                    .environmentObject(lockState)
                    .environmentObject(state))
        }
        lockOverlay.start()
        self.lockOverlay = lockOverlay

        settingsWindow = SettingsWindowController { [settings, calendar, weather, ambient] in
            SettingsView()
                .environmentObject(settings)
                .environmentObject(activities)
                .environmentObject(calendar)
                .environmentObject(weather)
                .environmentObject(ambient)
        }

        installMenuBarItem()

        // Keep awake, restored from the saved choice and kept in step with it.
        let screenLock = ScreenLockMonitor(settings: settings)
        screenLock.start()
        self.screenLock = screenLock

        keepAwake.setActive(settings.keepAwake)
        keepAwakeItem?.state = settings.keepAwake ? .on : .off
        settings.$keepAwake
            .sink { [weak self] on in
                self?.keepAwake.setActive(on)
                self?.keepAwakeItem?.state = on ? .on : .off
            }
            .store(in: &cancellables)

        // The calendar and weather ask for permission, so on first launch they
        // wait until the person has been through onboarding and granted access
        // there, rather than firing system prompts behind the welcome window.
        if OnboardingWindowController.hasOnboarded {
            startPermissionedServices()
        } else {
            onboarding.onFinish = { [weak self] in self?.startPermissionedServices() }
            DispatchQueue.main.async { [weak self] in self?.onboarding.show() }
        }
    }

    /// Start the services that request Calendar, Location, and Bluetooth access.
    private func startPermissionedServices() {
        if let activities { startBluetooth(activities: activities) }
        calendar.hiddenCalendarIDs = settings.hiddenCalendarIDs
        calendar.start()
        settings.$hiddenCalendarIDs
            .dropFirst()
            .sink { [weak self] hidden in self?.calendar.hiddenCalendarIDs = hidden }
            .store(in: &cancellables)
        startWeather()
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

    /// Take over the volume and brightness keys to show Reef's HUD, for whichever
    /// parts the person has turned on. Does nothing until Accessibility is
    /// granted, and is skipped while hosting tests.
    private func startSystemHUD(activities: LiveActivityCenter) {
        guard !isHostingTests else { return }
        let controller = SystemHUDController(settings: settings, activities: activities)
        controller.start()
        systemHUD = controller
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

        let keepAwakeItem = menu.addItem(
            withTitle: "Keep Awake",
            action: #selector(toggleKeepAwake),
            keyEquivalent: "")
        keepAwakeItem.target = self
        keepAwakeItem.state = settings.keepAwake ? .on : .off
        self.keepAwakeItem = keepAwakeItem

        let ambientItem = menu.addItem(
            withTitle: "Show Ambient Display",
            action: #selector(showAmbient),
            keyEquivalent: "")
        ambientItem.target = self

        menu.addItem(.separator())

        let about = menu.addItem(
            withTitle: "About Reef",
            action: #selector(openAbout),
            keyEquivalent: "")
        about.target = self

        let welcome = menu.addItem(
            withTitle: "Welcome to Reef…",
            action: #selector(openOnboarding),
            keyEquivalent: "")
        welcome.target = self

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

    @objc private func openOnboarding() {
        onboarding.show()
    }

    @objc private func toggleKeepAwake() {
        settings.keepAwake.toggle()
    }

    @objc private func showAmbient() {
        ambient?.showNow()
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
