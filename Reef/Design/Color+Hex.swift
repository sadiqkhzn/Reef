import AppKit
import SwiftUI

extension Color {
    /// Near-black or white — whichever reads cleanly as text/icons on top of
    /// this color used as a fill. Keeps active accent pills legible whatever
    /// accent the person picks (white text on a light accent fails contrast).
    var contrastingInk: Color {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return .white }
        let luminance = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        return luminance > 0.62 ? Color(red: 0.04, green: 0.04, blue: 0.055) : .white
    }

    /// Build a color from a `#RRGGBB` or `RRGGBB` string. Returns nil for any
    /// string that is not six hex digits, so callers can fall back.
    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = Int(text, radix: 16) else { return nil }

        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }
}
