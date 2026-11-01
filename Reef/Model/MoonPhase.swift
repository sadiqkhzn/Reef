import Foundation

/// The current moon phase, computed locally so the lock screen needs no network.
///
/// Uses the mean synodic month from a known new moon. This is accurate to within
/// a few hours — more than enough to name the phase and pick its symbol.
enum MoonPhase {
    /// Mean length of one lunation (new moon to new moon), in days.
    private static let synodicMonth = 29.530_588_853
    /// A reference new moon: 2000-01-06 18:14 UTC.
    private static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)

    /// Phase as a fraction of the cycle: 0 = new, 0.5 = full.
    static func fraction(at date: Date = Date()) -> Double {
        let days = date.timeIntervalSince(referenceNewMoon) / 86_400
        var phase = (days / synodicMonth).truncatingRemainder(dividingBy: 1)
        if phase < 0 { phase += 1 }
        return phase
    }

    /// Human name of the current phase, e.g. "Waxing Gibbous".
    static func name(at date: Date = Date()) -> String {
        Self.names[index(at: date)]
    }

    /// SF Symbol for the current phase.
    static func symbol(at date: Date = Date()) -> String {
        Self.symbols[index(at: date)]
    }

    /// Which of the eight named phases we are in.
    private static func index(at date: Date) -> Int {
        Int((fraction(at: date) * 8).rounded()) % 8
    }

    private static let names = [
        "New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous",
        "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent",
    ]

    private static let symbols = [
        "moonphase.new.moon", "moonphase.waxing.crescent", "moonphase.first.quarter",
        "moonphase.waxing.gibbous", "moonphase.full.moon", "moonphase.waning.gibbous",
        "moonphase.last.quarter", "moonphase.waning.crescent",
    ]
}
