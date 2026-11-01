import AppKit
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
    /// The event whose detail is open, if any.
    @State private var selected: CalendarEvent?

    private var upcoming: [CalendarEvent] {
        let now = Date()
        return events.filter { $0.end > now }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: headerHeight)

            if let selected {
                EventDetailView(event: selected, accent: accent)
            } else if mode == .month {
                MonthGridView(eventDays: eventDays, accent: accent)
            } else if upcoming.isEmpty {
                empty
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(upcoming) { event in
                            Button { selected = event } label: { row(event) }
                                .buttonStyle(.plain)
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
            if selected != nil {
                Button { selected = nil } label: {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(ReefTheme.Typography.caption)
                        .foregroundStyle(accent)
                        .padding(.horizontal, ReefTheme.Spacing.s)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accent.opacity(0.18)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Text("Calendar")
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(accent)
                    .padding(.horizontal, ReefTheme.Spacing.s)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(accent.opacity(0.18)))
            }
            Spacer(minLength: notchWidth + ReefTheme.Spacing.l)
            if selected == nil {
                modeToggle
            }
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
    }

    /// Step back from a detail to the list, or leave the island from the list.

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
            if event.meetingURL != nil {
                Image(systemName: "video.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(accent)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(ReefTheme.Ink.tertiary)
        }
        .contentShape(Rectangle())
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

/// The detail for one event: its title, when it is, where it is, and a one-tap
/// Join when a video-call link is attached.
private struct EventDetailView: View {
    let event: CalendarEvent
    var accent: Color

    private var color: Color { event.colorHex.flatMap(Color.init(hex:)) ?? accent }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: 3, height: 30)
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ReefTheme.Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                detailRow("clock", Self.when(event))
                if let location = event.location {
                    detailRow("mappin.and.ellipse", location)
                }

                if let link = event.meetingURL {
                    Button {
                        NSWorkspace.shared.open(link)
                    } label: {
                        Label("Join", systemImage: "video.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, ReefTheme.Spacing.m)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(accent))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ReefTheme.Spacing.l)
            .padding(.vertical, 8)
        }
    }

    private func detailRow(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(accent)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(ReefTheme.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A full "when" line: the day, and the start-to-end time range.
    private static func when(_ event: CalendarEvent) -> String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(event.start) {
            day = "Today"
        } else if calendar.isDateInTomorrow(event.start) {
            day = "Tomorrow"
        } else {
            day = event.start.formatted(.dateTime.weekday(.wide).month().day())
        }
        if event.isAllDay { return "\(day) · All day" }
        let start = event.start.formatted(.dateTime.hour().minute())
        let end = event.end.formatted(.dateTime.hour().minute())
        return "\(day) · \(start) – \(end)"
    }
}
