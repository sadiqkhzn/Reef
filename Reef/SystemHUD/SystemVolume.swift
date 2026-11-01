import CoreAudio
import Foundation

/// Reads and sets the system output volume through CoreAudio.
///
/// Everything works against the current default output device, resolved fresh
/// on each call, so it follows whatever route the person has chosen (built-in
/// speakers, headphones, an external set) with no bookkeeping here. Some outputs
/// expose a single main volume control, others only per-channel controls, so
/// reads and writes try the main element first and fall back to the left and
/// right channels.
enum SystemVolume {

    /// The current default output device, or `kAudioObjectUnknown` when none can
    /// be resolved.
    private static func defaultOutputDevice() -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr ? device : AudioObjectID(kAudioObjectUnknown)
    }

    /// The elements to try for a scalar volume: the main control, then the left
    /// and right channels for devices that only expose per-channel volume.
    private static let volumeElements: [AudioObjectPropertyElement] = [
        kAudioObjectPropertyElementMain, 1, 2,
    ]

    private static func volumeAddress(_ element: AudioObjectPropertyElement)
        -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element)
    }

    /// Volume scalar (0...1) of the default output, or nil when it cannot be
    /// read (for example an output with no software volume, like some HDMI
    /// routes). Per-channel readings are averaged.
    static func level() -> Float? {
        let device = defaultOutputDevice()
        guard device != AudioObjectID(kAudioObjectUnknown) else { return nil }

        var total: Float = 0
        var count: Float = 0
        for element in volumeElements {
            var address = volumeAddress(element)
            guard AudioObjectHasProperty(device, &address) else { continue }
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr
            else { continue }
            // The main element answers for the whole device on its own; stop
            // once it is read rather than mixing it with the channels.
            if element == kAudioObjectPropertyElementMain {
                return clamp(value)
            }
            total += value
            count += 1
        }
        return count > 0 ? clamp(total / count) : nil
    }

    /// Set the output volume (0...1). Returns true when at least one control
    /// accepted the new value.
    @discardableResult
    static func setLevel(_ value: Float) -> Bool {
        let device = defaultOutputDevice()
        guard device != AudioObjectID(kAudioObjectUnknown) else { return false }
        var target = clamp(value)

        var didSet = false
        for element in volumeElements {
            var address = volumeAddress(element)
            guard AudioObjectHasProperty(device, &address) else { continue }
            var settable: DarwinBoolean = false
            guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr,
                settable.boolValue else { continue }
            let size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectSetPropertyData(device, &address, 0, nil, size, &target) == noErr {
                didSet = true
                // The main element covers the device; no need to also walk the
                // channels.
                if element == kAudioObjectPropertyElementMain { break }
            }
        }
        return didSet
    }

    private static func muteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
    }

    /// Whether the default output is muted. Outputs with no mute control read as
    /// not muted.
    static func isMuted() -> Bool {
        let device = defaultOutputDevice()
        guard device != AudioObjectID(kAudioObjectUnknown) else { return false }
        var address = muteAddress()
        guard AudioObjectHasProperty(device, &address) else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr
        else { return false }
        return value != 0
    }

    /// Mute or unmute the default output. Returns true when the change was made.
    @discardableResult
    static func setMuted(_ muted: Bool) -> Bool {
        let device = defaultOutputDevice()
        guard device != AudioObjectID(kAudioObjectUnknown) else { return false }
        var address = muteAddress()
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr,
            settable.boolValue else { return false }
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &value) == noErr
    }

    private static func clamp(_ value: Float) -> Float { min(max(value, 0), 1) }
}
