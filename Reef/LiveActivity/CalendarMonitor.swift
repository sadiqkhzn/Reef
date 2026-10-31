import EventKit
import Foundation

/// Reads the next events from the person's calendars.
///
/// It asks for calendar access, then keeps a short list of today's upcoming
/// events, refreshing when the store changes and on a slow timer. Converting
/// EventKit's objects into plain `CalendarEvent`s keeps the rest of the app free
/// of EventKit.
@MainActor
final class CalendarMonitor: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var accessGranted = false
    /// The calendars available to show, for the settings list.
    @Published private(set) var calendars: [CalendarInfo] = []
    /// Start-of-day dates in the current month that have at least one event, for
    /// the month view's dots.
    @Published private(set) var monthEventDays: Set<Date> = []

    /// Identifiers of calendars to leave out. Set from the person's choice; a
    /// change re-filters the events.
    var hiddenCalendarIDs: Set<String> = [] {
        didSet { if oldValue != hiddenCalendarIDs { refresh() } }
    }

    private let store = EKEventStore()
    private var timer: Timer?
    private var observer: NSObjectProtocol?

    /// How far ahead to pull events for.
    private let window: TimeInterval = 3 * 24 * 3600

    func start() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            Task { @MainActor in
                guard let self else { return }
                self.accessGranted = granted
                guard granted else { return }
                self.beginWatching()
                self.refresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    private func beginWatching() {
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }

        // A slow refresh keeps the list honest as events pass and new ones are
        // added; the countdown itself updates live in the view.
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-3600),
            end: now.addingTimeInterval(window),
            calendars: nil)

        calendars = store.calendars(for: .event)
            .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, colorHex: Self.hex($0.cgColor)) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        let mapped = store.events(matching: predicate)
            .filter { !hiddenCalendarIDs.contains($0.calendar?.calendarIdentifier ?? "") }
            .map { event in
                CalendarEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Event",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    colorHex: Self.hex(event.calendar?.cgColor),
                    calendarID: event.calendar?.calendarIdentifier)
            }
        events = mapped.sorted { $0.start < $1.start }
        refreshMonth(now: now)
    }

    /// Collect the days of the current month that have an event, for the grid.
    private func refreshMonth(now: Date) {
        let calendar = Calendar.current
        guard let monthRange = calendar.dateInterval(of: .month, for: now) else {
            monthEventDays = []
            return
        }
        let predicate = store.predicateForEvents(
            withStart: monthRange.start, end: monthRange.end, calendars: nil)

        var days: Set<Date> = []
        for event in store.events(matching: predicate)
        where !hiddenCalendarIDs.contains(event.calendar?.calendarIdentifier ?? "") {
            days.insert(calendar.startOfDay(for: event.startDate))
        }
        monthEventDays = days
    }

    /// A `#RRGGBB` string for a calendar color, or nil when it has none.
    private static func hex(_ color: CGColor?) -> String? {
        guard let color, let components = color.components, components.count >= 3 else { return nil }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
