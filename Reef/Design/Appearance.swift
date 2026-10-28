import SwiftUI

/// What the island body is made of.
enum IslandMaterial: String, CaseIterable, Identifiable {
    /// Solid black. Disappears into the physical notch and reads the same on
    /// every wallpaper.
    case midnight
    /// Frosted glass: a dark, blurred view of the desktop behind the island
    /// with a light rim along the edge. Works on every supported macOS.
    case frosted
    /// The system Liquid Glass material on macOS 26 and later. Falls back to
    /// frosted glass on earlier systems.
    case liquid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .midnight: return "Midnight"
        case .frosted: return "Frosted"
        case .liquid: return "Liquid Glass"
        }
    }

    var summary: String {
        switch self {
        case .midnight: return "Solid black that blends into the notch."
        case .frosted: return "Blurred glass with a soft rim."
        case .liquid: return "System glass that bends the light behind it."
        }
    }

    /// True when this build and system can draw the Liquid Glass material.
    static var isLiquidGlassAvailable: Bool {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            return true
        }
        #endif
        return false
    }

    /// The material that will actually be drawn, given whether Liquid Glass is
    /// available and whether the person asked the system to reduce
    /// transparency. Reduced transparency always wins and draws solid.
    func resolved(liquidGlassAvailable: Bool, reduceTransparency: Bool) -> IslandMaterial {
        if reduceTransparency { return .midnight }
        if self == .liquid && !liquidGlassAvailable { return .frosted }
        return self
    }
}

/// Accent color used for selection, progress rings, and meters. Status colors
/// such as charging green and low-battery red are not affected.
enum AccentChoice: String, CaseIterable, Identifiable {
    case lagoon
    case iris
    case coral
    case sunset
    case mint
    case pearl

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .lagoon: return Color(red: 0.30, green: 0.78, blue: 0.98)
        case .iris: return Color(red: 0.62, green: 0.52, blue: 1.0)
        case .coral: return Color(red: 1.0, green: 0.48, blue: 0.47)
        case .sunset: return Color(red: 1.0, green: 0.62, blue: 0.25)
        case .mint: return Color(red: 0.40, green: 0.90, blue: 0.76)
        case .pearl: return Color(red: 0.92, green: 0.92, blue: 0.95)
        }
    }
}

/// How the island moves between states.
enum MotionStyle: String, CaseIterable, Identifiable {
    /// Critically damped: settles without overshoot.
    case smooth
    /// Quicker and tighter, for people who want it out of the way fast.
    case snappy
    /// A small overshoot on open, closest to the iPhone Dynamic Island.
    case bouncy

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    /// Parameters for one spring.
    struct Spring: Equatable {
        var response: Double
        var dampingFraction: Double
    }

    /// Spring used when the island opens.
    var open: Spring {
        switch self {
        case .smooth: return Spring(response: 0.42, dampingFraction: 1.0)
        case .snappy: return Spring(response: 0.30, dampingFraction: 0.92)
        case .bouncy: return Spring(response: 0.46, dampingFraction: 0.74)
        }
    }

    /// Spring used when the island closes. A touch slower than opening, and
    /// never bouncy, so the island settles back into the notch cleanly.
    var close: Spring {
        switch self {
        case .smooth: return Spring(response: 0.45, dampingFraction: 1.0)
        case .snappy: return Spring(response: 0.32, dampingFraction: 1.0)
        case .bouncy: return Spring(response: 0.44, dampingFraction: 0.9)
        }
    }

    /// Spring for the quick grow when the pointer first arrives.
    var peek: Spring {
        switch self {
        case .smooth: return Spring(response: 0.30, dampingFraction: 0.80)
        case .snappy: return Spring(response: 0.22, dampingFraction: 0.85)
        case .bouncy: return Spring(response: 0.30, dampingFraction: 0.62)
        }
    }

    /// Spring for wings sliding out around the notch for a live activity.
    var wings: Spring {
        switch self {
        case .smooth: return Spring(response: 0.38, dampingFraction: 0.95)
        case .snappy: return Spring(response: 0.28, dampingFraction: 0.9)
        case .bouncy: return Spring(response: 0.42, dampingFraction: 0.7)
        }
    }

    /// Build an animation for `spring`. With Reduce Motion on, a short fade
    /// timing replaces the spring so nothing overshoots or travels far.
    static func animation(_ spring: Spring, reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.18)
        }
        return .spring(response: spring.response, dampingFraction: spring.dampingFraction)
    }
}
