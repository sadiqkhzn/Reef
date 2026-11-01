import AppKit
import CoreGraphics

/// A volume or brightness key on the keyboard's top row.
enum MediaKey: Equatable {
    case volumeUp
    case volumeDown
    case mute
    case brightnessUp
    case brightnessDown

    /// Map from the key code carried by a system-defined event. Returns nil for
    /// any other special key (play/pause, Mission Control, and the rest), which
    /// is left for the system to handle.
    init?(systemDefinedKeyCode code: Int32) {
        switch code {
        case 0: self = .volumeUp        // NX_KEYTYPE_SOUND_UP
        case 1: self = .volumeDown      // NX_KEYTYPE_SOUND_DOWN
        case 2: self = .brightnessUp    // NX_KEYTYPE_BRIGHTNESS_UP
        case 3: self = .brightnessDown  // NX_KEYTYPE_BRIGHTNESS_DOWN
        case 7: self = .mute            // NX_KEYTYPE_MUTE
        default: return nil
        }
    }
}

/// One press of a media key, with enough detail to tell a first press from the
/// auto-repeats that follow while it is held, and from the release.
struct MediaKeyPress: Equatable {
    var key: MediaKey
    var isDown: Bool
    var isRepeat: Bool
}

/// Watches the keyboard's volume and brightness keys and offers each press to a
/// handler that decides whether to take it over.
///
/// It uses a session event tap, which needs Accessibility permission; without
/// it the tap cannot be created and `start()` reports failure. The handler
/// returns true to swallow a press (so the system never sees it, and its own
/// overlay never appears) or false to let it through unchanged. That lets the
/// owner fall back to normal system behaviour whenever it cannot act, so the
/// keys never feel dead.
final class MediaKeyMonitor {

    /// Called on the main thread for each volume or brightness key event. Return
    /// true to swallow it, false to pass it through to the system.
    var onKeyPress: ((MediaKeyPress) -> Bool)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// True while the tap is installed and listening.
    var isRunning: Bool { tap != nil }

    /// Install the tap. Returns false when it cannot be created, which almost
    /// always means Accessibility permission has not been granted yet.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        // System-defined events (which carry the media keys) are event type 14;
        // there is no named CGEventType for it, so the mask is built by hand.
        let mask: CGEventMask = 1 << 14

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<MediaKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// Remove the tap and stop listening.
    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        tap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables a tap that stalls or that fires during certain
        // input; re-enable it so interception keeps working rather than quietly
        // dying and leaving the keys half-handled.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type.rawValue == 14,
            let nsEvent = NSEvent(cgEvent: event),
            nsEvent.subtype.rawValue == 8  // NX_SUBTYPE_AUX_CONTROL_BUTTONS
        else {
            return Unmanaged.passUnretained(event)
        }

        let data1 = nsEvent.data1
        let keyCode = Int32((data1 & 0xFFFF_0000) >> 16)
        let keyFlags = data1 & 0x0000_FFFF
        let isDown = ((keyFlags & 0xFF00) >> 8) == 0x0A
        let isRepeat = (keyFlags & 0x1) == 1

        guard let key = MediaKey(systemDefinedKeyCode: keyCode) else {
            return Unmanaged.passUnretained(event)
        }

        let press = MediaKeyPress(key: key, isDown: isDown, isRepeat: isRepeat)
        if onKeyPress?(press) == true {
            return nil
        }
        return Unmanaged.passUnretained(event)
    }
}
