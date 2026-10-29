import CoreAudio
import Foundation

/// Reports where system audio is routed as it changes.
///
/// Two things are watched: the default output device (which switches when a
/// Bluetooth, USB, HDMI, or AirPlay output is chosen) and the active data source
/// of that device (which flips to "Headphones" when something is put in the
/// built-in jack). Changes during a short settle period after starting are
/// ignored so the route the app launches with is not announced.
@MainActor
final class AudioOutputMonitor {
    /// Called with the new output whenever the route changes.
    var onChange: ((AudioOutput) -> Void)?

    private var started = false
    private var startedAt = Date.distantPast
    private let settlePeriod: TimeInterval = 1.5
    private var current: AudioOutput?

    /// The device whose data source is currently being watched.
    private var watchedDevice = AudioObjectID(kAudioObjectUnknown)

    private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    private var dataSourceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDataSource,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    private var defaultListener: AudioObjectPropertyListenerBlock?
    private var dataSourceListener: AudioObjectPropertyListenerBlock?

    func start() {
        guard !started else { return }
        started = true
        startedAt = Date()

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.defaultDeviceChanged() }
        }
        defaultListener = listener
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, DispatchQueue.main, listener)

        current = currentOutput()
        watchDataSource(of: defaultOutputDevice() ?? AudioObjectID(kAudioObjectUnknown))
    }

    func stop() {
        if let listener = defaultListener {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, DispatchQueue.main, listener)
            defaultListener = nil
        }
        watchDataSource(of: AudioObjectID(kAudioObjectUnknown))
        started = false
    }

    // MARK: - Change handling

    private func defaultDeviceChanged() {
        watchDataSource(of: defaultOutputDevice() ?? AudioObjectID(kAudioObjectUnknown))
        emitIfChanged()
    }

    private func emitIfChanged() {
        let output = currentOutput()
        guard output != current else { return }
        current = output
        guard Date().timeIntervalSince(startedAt) > settlePeriod, let output else { return }
        onChange?(output)
    }

    /// Point the data-source listener at `device`, moving it off the previous one.
    private func watchDataSource(of device: AudioObjectID) {
        if watchedDevice != AudioObjectID(kAudioObjectUnknown), let block = dataSourceListener {
            AudioObjectRemovePropertyListenerBlock(watchedDevice, &dataSourceAddress, DispatchQueue.main, block)
        }
        dataSourceListener = nil
        watchedDevice = device
        guard device != AudioObjectID(kAudioObjectUnknown) else { return }

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.emitIfChanged() }
        }
        dataSourceListener = block
        AudioObjectAddPropertyListenerBlock(device, &dataSourceAddress, DispatchQueue.main, block)
    }

    // MARK: - Reading the current route

    private func currentOutput() -> AudioOutput? {
        guard let device = defaultOutputDevice() else { return nil }
        let transport = transportType(of: device)
        let source = dataSourceName(of: device)
        let label = deviceName(of: device)
        let kind = AudioOutputKind.classify(
            transportType: transport, dataSourceName: source, deviceName: label)

        // The data source name ("MacBook Pro Speakers", "External Headphones")
        // is friendlier than the device name for the built-in device.
        let name: String
        if (kind == .headphones || kind == .builtInSpeakers), let source, !source.isEmpty {
            name = source
        } else {
            name = label ?? kind.title
        }
        return AudioOutput(name: name, kind: kind)
    }

    private func defaultOutputDevice() -> AudioObjectID? {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, 0, nil, &size, &device)
        guard status == noErr, device != AudioObjectID(kAudioObjectUnknown) else { return nil }
        return device
    }

    private func transportType(of device: AudioObjectID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return value
    }

    private func deviceName(of device: AudioObjectID) -> String? {
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
    private func dataSourceName(of device: AudioObjectID) -> String? {
        var sourceID: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &dataSourceAddress, 0, nil, &size, &sourceID) == noErr else {
            return nil
        }

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
