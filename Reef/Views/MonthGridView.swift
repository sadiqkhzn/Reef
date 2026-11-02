import SwiftUI

/// A compact month grid for the calendar page. Today is ringed in the accent
/// color, and days with an event carry a small dot.
struct MonthGridView: View {
    /// Start-of-day dates in the month that have events.
    var eventDays: Set<Date>
    var accent: Color

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date(), format: .dateTime.month(.wide).year())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ReefTheme.Ink.primary)

            LazyVGrid(columns: columns, spacing: 1) {
                // Keyed by position: weekday initials repeat (S, T), so keying by
                // the letter would drop the duplicates.
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(ReefTheme.Ink.tertiary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    dayCell(day)
                }
            }
        }
        .padding(.horizontal, ReefTheme.Spacing.s)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let isToday = calendar.isDateInToday(day)
            let hasEvent = eventDays.contains(calendar.startOfDay(for: day))
            // The event dot is an overlay so it adds no row height.
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 10, weight: isToday ? .bold : .regular, design: .rounded))
                .foregroundStyle(isToday ? accent.contrastingInk : ReefTheme.Ink.primary)
                .frame(width: 15, height: 15)
                .background {
                    if isToday {
                        Circle().fill(accent)
                    }
                }
                .overlay(alignment: .bottom) {
                    if hasEvent {
                        Circle().fill(accent).frame(width: 3, height: 3).offset(y: 3)
                    }
                }
                .frame(maxWidth: .infinity)
        } else {
            Color.clear.frame(height: 15)
        }
    }

    /// Localized one-letter weekday headers, starting on the locale's first day.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// The days of the current month, padded with nils for the leading blanks.
    private var days: [Date?] {
        let now = Date()
        guard let monthRange = calendar.dateInterval(of: .month, for: now),
            let dayCount = calendar.range(of: .day, in: .month, for: now)?.count else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: monthRange.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        var result: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            result.append(calendar.date(byAdding: .day, value: offset, to: monthRange.start))
        }
        return result
    }
}
