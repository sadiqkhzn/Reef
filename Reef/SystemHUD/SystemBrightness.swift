import CoreGraphics
import Foundation

/// Reads and sets display brightness.
///
/// macOS has no public API for display brightness, so the two calls are resolved
/// at runtime from a system framework. When they cannot be found, or a display
/// does not support software brightness (common for external monitors), the
/// reads return nil and the writes report failure, so callers can fall back to
/// letting the system handle the key itself.
enum SystemBrightness {

    private typealias GetBrightness =
        @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness =
        @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY)

    private static let getBrightness: GetBrightness? = handle.flatMap { handle in
        dlsym(handle, "DisplayServicesGetBrightness").map {
            unsafeBitCast($0, to: GetBrightness.self)
        }
    }

    private static let setBrightness: SetBrightness? = handle.flatMap { handle in
        dlsym(handle, "DisplayServicesSetBrightness").map {
            unsafeBitCast($0, to: SetBrightness.self)
        }
    }

    /// True when both brightness calls were resolved, so the feature can work.
    static var isAvailable: Bool { getBrightness != nil && setBrightness != nil }

    /// Brightness (0...1) of the display, or nil when it cannot be read.
    static func level(for display: CGDirectDisplayID = CGMainDisplayID()) -> Float? {
        guard let getBrightness else { return nil }
        var value: Float = 0
        guard getBrightness(display, &value) == 0 else { return nil }
        return min(max(value, 0), 1)
    }

    /// Set the display brightness (0...1). Returns true on success.
    @discardableResult
    static func setLevel(_ value: Float, for display: CGDirectDisplayID = CGMainDisplayID())
        -> Bool {
        guard let setBrightness else { return false }
        return setBrightness(display, min(max(value, 0), 1)) == 0
    }
}
