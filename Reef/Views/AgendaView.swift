import SwiftUI

/// The calendar page: a short agenda of upcoming events, each with its time and
/// calendar color. Scrolls when there are more than fit.
struct AgendaView: View {
    let events: [CalendarEvent]
    var accent: Color
    var headerHeight: CGFloat
    var notchWidth: CGFloat
    /// Days in the current month with events, for the month grid.
    var eventDays: Set<Date> = []
    /// Leave the open island (back to home).
    var onClose: () -> Void

    private enum Mode { case list, month }
    @State private var mode: Mode = .list

    private var upcoming: [CalendarEvent] {
        let now = Date()
        return events.filter { $0.end > now }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: headerHeight)

            if mode == .month {
                MonthGridView(eventDays: eventDays, accent: accent)
            } else if upcoming.isEmpty {
                empty
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(upcoming) { event in
                            row(event)
                        }
                    }
                    .padding(.horizontal, ReefTheme.Spacing.l)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button(action: onClose) {
                Label("Calendar", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(accent)
                    .padding(.horizontal, ReefTheme.Spacing.s)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(accent.opacity(0.18)))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer(minLength: notchWidth + ReefTheme.Spacing.l)
            modeToggle
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
    }

    /// Switches the page between the agenda list and the month grid.
    private var modeToggle: some View {
        Button {
            mode = mode == .list ? .month : .list
        } label: {
            Image(systemName: mode == .list ? "calendar" : "list.bullet")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(mode == .list ? "Month view" : "List view")
    }

    private var empty: some View {
        VStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(ReefTheme.Ink.secondary)
            Text("Nothing coming up")
                .font(ReefTheme.Typography.caption)
                .foregroundStyle(ReefTheme.Ink.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ event: CalendarEvent) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.colorHex.flatMap(Color.init(hex:)) ?? accent)
                .frame(width: 3, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ReefTheme.Ink.primary)
                    .lineLimit(1)
                Text(Self.when(event))
                    .font(.system(size: 10))
                    .foregroundStyle(ReefTheme.Ink.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    /// "All day" or a day-and-time label like "Today 3:00 PM" / "Fri 9:30 AM".
    private static func when(_ event: CalendarEvent) -> String {
        if event.isAllDay { return "All day" }

        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(event.start) {
            day = "Today"
        } else if calendar.isDateInTomorrow(event.start) {
            day = "Tomorrow"
        } else {
            day = event.start.formatted(.dateTime.weekday(.abbreviated))
        }
        let time = event.start.formatted(.dateTime.hour().minute())
        return "\(day) \(time)"
    }
}
