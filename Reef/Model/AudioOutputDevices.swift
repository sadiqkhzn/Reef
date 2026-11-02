import CoreAudio
import Foundation

/// One output device the system audio can be routed to.
struct OutputDevice: Identifiable, Equatable {
    let id: AudioObjectID
    let output: AudioOutput
    var name: String { output.name }
    var symbol: String { output.kind.symbol }
}

/// Lists the available output devices and switches the system default between
/// them, using the same CoreAudio properties the output monitor reads. These
/// are plain C calls on the hardware object, so no extra entitlement is needed.
enum AudioOutputDevices {

    /// Every device that can play audio out, friendliest name first picked the
    /// same way the monitor names the current route.
    static func available() -> [OutputDevice] {
        allDeviceIDs().compactMap { id in
            guard hasOutputStreams(id) else { return nil }
            let transport = transportType(of: id)
            let source = dataSourceName(of: id)
            let label = deviceName(of: id)
            let kind = AudioOutputKind.classify(
                transportType: transport, dataSourceName: source, deviceName: label)
            let name: String
            if (kind == .headphones || kind == .builtInSpeakers), let source, !source.isEmpty {
                name = source
            } else {
                name = label ?? kind.title
            }
            return OutputDevice(id: id, output: AudioOutput(name: name, kind: kind))
        }
    }

    /// The device audio is currently going to, so the picker can mark it.
    static func currentDefaultID() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        guard status == noErr, device != AudioObjectID(kAudioObjectUnknown) else { return nil }
        return device
    }

    /// Route system audio to `device` by making it the default output.
    @discardableResult
    static func setDefault(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var id = device
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
            UInt32(MemoryLayout<AudioObjectID>.size), &id)
        return status == noErr
    }

    // MARK: - Volume & mute

    /// The device's output volume (0…1), from the main channel when it has one,
    /// otherwise averaged across the stereo channels. Nil when it exposes none.
    static func volume(of device: AudioObjectID) -> Float? {
        if let main = scalarVolume(device, channel: kAudioObjectPropertyElementMain) {
            return main
        }
        let left = scalarVolume(device, channel: 1)
        let right = scalarVolume(device, channel: 2)
        let channels = [left, right].compactMap { $0 }
        guard !channels.isEmpty else { return nil }
        return channels.reduce(0, +) / Float(channels.count)
    }

    /// Set the device's output volume (0…1) on the main channel, falling back to
    /// the stereo channels when there is no settable main channel.
    static func setVolume(_ value: Float, on device: AudioObjectID) {
        let clamped = min(1, max(0, value))
        if setScalarVolume(clamped, device, channel: kAudioObjectPropertyElementMain) { return }
        _ = setScalarVolume(clamped, device, channel: 1)
        _ = setScalarVolume(clamped, device, channel: 2)
    }

    static func isMuted(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectHasProperty(device, &address),
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr
        else { return false }
        return muted != 0
    }

    @discardableResult
    static func setMuted(_ muted: Bool, on device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var settable = DarwinBoolean(false)
        guard AudioObjectHasProperty(device, &address),
            AudioObjectIsPropertySettable(device, &address, &settable) == noErr,
            settable.boolValue
        else { return false }
        var value: UInt32 = muted ? 1 : 0
        return AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
    }

    private static func scalarVolume(_ device: AudioObjectID, channel: UInt32) -> Float? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: channel)
        var value: Float = 0
        var size = UInt32(MemoryLayout<Float>.size)
        guard AudioObjectHasProperty(device, &address),
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr
        else { return nil }
        return value
    }

    @discardableResult
    private static func setScalarVolume(
        _ value: Float, _ device: AudioObjectID, channel: UInt32
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: channel)
        var settable = DarwinBoolean(false)
        guard AudioObjectHasProperty(device, &address),
            AudioObjectIsPropertySettable(device, &address, &settable) == noErr,
            settable.boolValue
        else { return false }
        var newValue = value
        return AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<Float>.size), &newValue) == noErr
    }

    // MARK: - Reading

    private static func allDeviceIDs() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr,
            size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: AudioObjectID(kAudioObjectUnknown), count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr
        else { return [] }
        return ids
    }

    /// Whether the device has at least one output stream, so it can play audio.
    private static func hasOutputStreams(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr else {
            return false
        }
        return size > 0
    }

    private static func transportType(of device: AudioObjectID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return value
    }

    private static func deviceName(of device: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name)
        guard status == noErr, let name else { return nil }
        return name.takeRetainedValue() as String
    }

    /// The name of the device's active output data source, when it has one.
    private static func dataSourceName(of device: AudioObjectID) -> String? {
        var dataSourceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSource,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var sourceID: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(
            device, &dataSourceAddress, 0, nil, &size, &sourceID) == noErr else { return nil }

        var name: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &sourceID) { input -> OSStatus in
            withUnsafeMutablePointer(to: &name) { output -> OSStatus in
                var translation = AudioValueTranslation(
                    mInputData: UnsafeMutableRawPointer(input),
                    mInputDataSize: UInt32(MemoryLayout<UInt32>.size),
                    mOutputData: UnsafeMutableRawPointer(output),
                    mOutputDataSize: UInt32(MemoryLayout<Unmanaged<CFString>?>.size))
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDataSourceNameForIDCFString,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain)
                var translationSize = UInt32(MemoryLayout<AudioValueTranslation>.size)
                return AudioObjectGetPropertyData(
                    device, &address, 0, nil, &translationSize, &translation)
            }
        }
        guard status == noErr, let name else { return nil }
        return name.takeRetainedValue() as String
    }
}
