import CoreAudio
import Foundation

/// Where system audio is currently going.
struct AudioOutput: Equatable {
    var name: String
    var kind: AudioOutputKind
}

/// The sort of output the audio is routed to, so the wings can show a fitting
/// symbol and label. Guessed from the device's transport type, with the data
/// source name splitting built-in speakers from the headphone jack.
enum AudioOutputKind: Equatable {
    case builtInSpeakers
    case headphones
    case bluetooth
    case usb
    case hdmi
    case display
    case airPlay
    case other

    /// Classify from CoreAudio's transport type, the built-in device's active
    /// data source name (which reads "Headphones" when something is in the jack),
    /// and the device name. A wired or USB set that names itself as earbuds or
    /// headphones reads as headphones rather than by its bare transport. Kept
    /// pure so it can be tested without any audio hardware.
    static func classify(
        transportType: UInt32,
        dataSourceName: String? = nil,
        deviceName: String? = nil
    ) -> AudioOutputKind {
        func soundsLikeHeadphones(_ text: String?) -> Bool {
            guard let text = text?.lowercased() else { return false }
            return ["headphone", "earpod", "airpod", "earbud", "buds", "beats"].contains { text.contains($0) }
        }

        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            if soundsLikeHeadphones(dataSourceName) { return .headphones }
            return .builtInSpeakers
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return .bluetooth
        case kAudioDeviceTransportTypeUSB:
            return soundsLikeHeadphones(deviceName) ? .headphones : .usb
        case kAudioDeviceTransportTypeHDMI:
            return .hdmi
        case kAudioDeviceTransportTypeDisplayPort:
            return .display
        case kAudioDeviceTransportTypeAirPlay:
            return .airPlay
        default:
            return soundsLikeHeadphones(deviceName) ? .headphones : .other
        }
    }

    /// Short word for the center of the wings when there is no notch in the way.
    var title: String {
        switch self {
        case .builtInSpeakers: return "Speakers"
        case .headphones: return "Headphones"
        case .bluetooth: return "Bluetooth"
        case .usb: return "USB"
        case .hdmi: return "HDMI"
        case .display: return "Display"
        case .airPlay: return "AirPlay"
        case .other: return "Output"
        }
    }

    /// SF Symbol for the leading wing.
    var symbol: String {
        switch self {
        case .builtInSpeakers: return "speaker.wave.2.fill"
        case .headphones: return "headphones"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        case .usb: return "cable.connector"
        case .hdmi: return "tv"
        case .display: return "display"
        case .airPlay: return "airplayaudio"
        case .other: return "speaker.wave.2.fill"
        }
    }
}
