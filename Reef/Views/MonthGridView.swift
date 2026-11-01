import SwiftUI

/// A compact month grid for the calendar page. Today is ringed in the accent
/// color, and days with an event carry a small dot.
struct MonthGridView: View {
    /// Start-of-day dates in the month that have events.
    var eventDays: Set<Date>
    var accent: Color

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date(), format: .dateTime.month(.wide).year())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ReefTheme.Ink.primary)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(ReefTheme.Ink.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    dayCell(day)
                }
            }
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let isToday = calendar.isDateInToday(day)
            let hasEvent = eventDays.contains(calendar.startOfDay(for: day))
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 10, weight: isToday ? .bold : .regular, design: .rounded))
                    .foregroundStyle(isToday ? Color.black : ReefTheme.Ink.primary)
                    .frame(width: 18, height: 18)
                    .background {
                        if isToday {
                            Circle()
                                .fill(accent.gradient)
                                .shadow(color: accent.opacity(0.5), radius: 3)
                        }
                    }
                Circle()
                    .fill(hasEvent ? accent : .clear)
                    .frame(width: 3, height: 3)
            }
            .frame(maxWidth: .infinity)
        } else {
            Color.clear.frame(height: 22)
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
