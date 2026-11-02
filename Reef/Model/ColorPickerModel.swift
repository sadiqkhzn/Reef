import AppKit
import SwiftUI

/// One sampled color, with the formats people copy.
struct PickedColor: Identifiable, Equatable, Codable {
    var id = UUID()
    /// Components in 0–1 sRGB.
    var red: Double
    var green: Double
    var blue: Double

    init(id: UUID = UUID(), red: Double, green: Double, blue: Double) {
        self.id = id
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(_ nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.init(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent)
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }

    private var bytes: (Int, Int, Int) {
        (Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    var hex: String {
        let (r, g, b) = bytes
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var rgb: String {
        let (r, g, b) = bytes
        return "\(r), \(g), \(b)"
    }

    /// A SwiftUI `Color(...)` initializer string, handy for engineers.
    var swift: String {
        String(format: "Color(red: %.2f, green: %.2f, blue: %.2f)", red, green, blue)
    }

    var hsl: String {
        let r = red, g = green, b = blue
        let maxV = max(r, g, b), minV = min(r, g, b)
        let l = (maxV + minV) / 2
        var h = 0.0, s = 0.0
        if maxV != minV {
            let d = maxV - minV
            s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
            switch maxV {
            case r: h = (g - b) / d + (g < b ? 6 : 0)
            case g: h = (b - r) / d + 2
            default: h = (r - g) / d + 4
            }
            h /= 6
        }
        return "\(Int((h * 360).rounded()))°, \(Int((s * 100).rounded()))%, \(Int((l * 100).rounded()))%"
    }
}

/// Holds the eyedropper and the recent swatches, persisted across launches.
@MainActor
final class ColorPickerModel: ObservableObject {
    @Published private(set) var recents: [PickedColor] = []
    @Published var selected: PickedColor?

    private let key = "colorPicker.recents"
    private let maxRecents = 10

    /// Shown before the first pick so the orb glows and every format row carries a
    /// real, copyable value (Reef's sky accent, #38BDF8).
    private static let seed = PickedColor(red: 0.22, green: 0.74, blue: 0.97)

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
            let saved = try? JSONDecoder().decode([PickedColor].self, from: data),
            !saved.isEmpty {
            recents = saved
            selected = saved.first
        } else {
            selected = Self.seed
        }
    }

    /// Show the system eyedropper and record whatever is sampled.
    func pick() {
        NSColorSampler().show { [weak self] nsColor in
            guard let self, let nsColor else { return }
            let picked = PickedColor(nsColor)
            self.selected = picked
            self.addRecent(picked)
        }
    }

    func select(_ color: PickedColor) {
        selected = color
    }

    private func addRecent(_ color: PickedColor) {
        recents.removeAll { $0.hex == color.hex }
        recents.insert(color, at: 0)
        if recents.count > maxRecents { recents.removeLast(recents.count - maxRecents) }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(recents) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
