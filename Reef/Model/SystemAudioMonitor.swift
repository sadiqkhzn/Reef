import AudioToolbox
import CoreAudio
import Foundation
import os.lock

/// Reads the level of whatever is playing through the system, using a Core Audio
/// process tap (macOS 14.2+), and publishes a short history of recent loudness
/// so the equalizer can move with the real music rather than a canned animation.
///
/// Capturing audio asks for the system audio recording permission the first time
/// it starts. The tap and its aggregate device are private, so they never show
/// up as a real output device. On older systems it simply does nothing.
@MainActor
final class SystemAudioMonitor: ObservableObject {
    /// Recent loudness, oldest to newest, each 0...1. Empty when not running.
    @Published private(set) var levels: [Float] = []

    private var tapID: AudioObjectID = 0
    private var aggregateID: AudioDeviceID = 0
    private var procID: AudioDeviceIOProcID?
    private var running = false

    /// Latest loudness written by the audio callback, read on a timer. Guarded
    /// by a lock, and marked unsafe because the real-time thread touches it.
    private nonisolated(unsafe) var latestLevel: Float = 0
    private nonisolated(unsafe) var levelLock = os_unfair_lock()
    private var history = [Float](repeating: 0, count: 5)
    private var sampleTimer: Timer?

    func start() {
        guard !running else { return }
        guard #available(macOS 14.2, *), installTap() else {
            stop()
            return
        }
        running = true

        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        RunLoop.main.add(timer, forMode: .common)
        sampleTimer = timer
    }

    func stop() {
        running = false
        sampleTimer?.invalidate()
        sampleTimer = nil
        teardownTap()
        levels = []
    }

    private func sample() {
        os_unfair_lock_lock(&levelLock)
        let level = latestLevel
        os_unfair_lock_unlock(&levelLock)

        history.removeFirst()
        history.append(level)
        levels = history
    }

    // MARK: - Core Audio setup

    @available(macOS 14.2, *)
    private func installTap() -> Bool {
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.isPrivate = true
        description.muteBehavior = .unmuted

        guard AudioHardwareCreateProcessTap(description, &tapID) == noErr, tapID != 0 else {
            return false
        }

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Reef Audio Tap",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapUIDKey: description.uuid.uuidString],
            ],
        ]
        guard AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID) == noErr,
            aggregateID != 0 else {
            return false
        }

        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, nil) {
            [weak self] _, inInputData, _, _, _ in
            self?.process(inInputData)
        }
        guard status == noErr, let procID else { return false }

        return AudioDeviceStart(aggregateID, procID) == noErr
    }

    private func teardownTap() {
        if let procID, aggregateID != 0 {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        procID = nil
        if aggregateID != 0 { AudioHardwareDestroyAggregateDevice(aggregateID) }
        aggregateID = 0
        if tapID != 0, #available(macOS 14.2, *) { AudioHardwareDestroyProcessTap(tapID) }
        tapID = 0
    }

    /// Runs on the audio thread. Computes the loudness of one buffer and stashes
    /// it for the main-thread timer to pick up.
    private nonisolated func process(_ bufferList: UnsafePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: bufferList))
        guard let first = buffers.first, let data = first.mData else { return }

        let count = Int(first.mDataByteSize) / MemoryLayout<Float>.size
        guard count > 0 else { return }
        let samples = data.assumingMemoryBound(to: Float.self)

        var sum: Float = 0
        for i in 0..<count {
            sum += samples[i] * samples[i]
        }
        let rms = (sum / Float(count)).squareRoot()
        let level = min(1, rms * 3.5)

        os_unfair_lock_lock(&levelLock)
        latestLevel = level
        os_unfair_lock_unlock(&levelLock)
    }
}
