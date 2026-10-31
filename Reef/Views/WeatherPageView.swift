import SwiftUI

/// The weather page of the open island: the current conditions, a strip of the
/// next hours, and a short list of the coming days.
struct WeatherPageView: View {
    var snapshot: WeatherSnapshot?
    var forecast: WeatherForecast?
    var accent: Color
    var headerHeight: CGFloat
    var notchWidth: CGFloat
    /// Leave the open island (back to home).
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: headerHeight)

            if let snapshot {
                content(snapshot)
            } else {
                empty
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button(action: onClose) {
                Label("Weather", systemImage: "chevron.left")
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
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
    }

    private func content(_ snapshot: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            current(snapshot)
            if let hours = forecast?.upcomingHours(), !hours.isEmpty {
                hourStrip(hours)
            }
            if let days = forecast?.upcomingDays(), !days.isEmpty {
                dayList(days)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
        .padding(.vertical, 6)
    }

    private func current(_ snapshot: WeatherSnapshot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: snapshot.condition.symbol)
                .font(.system(size: 26))
                .foregroundStyle(accent)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.temperatureText)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(ReefTheme.Ink.primary)
                Text(snapshot.condition.label)
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(ReefTheme.Ink.secondary)
            }
            Spacer(minLength: 0)
            if let high = snapshot.highText, let low = snapshot.lowText {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("H \(high)")
                        .foregroundStyle(ReefTheme.Ink.primary)
                    Text("L \(low)")
                        .foregroundStyle(ReefTheme.Ink.secondary)
                }
                .font(ReefTheme.Typography.caption)
            }
        }
    }

    private func hourStrip(_ hours: [HourForecast]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(hours) { hour in
                    VStack(spacing: 3) {
                        Text(Self.hourLabel(hour.date))
                            .font(.system(size: 9))
                            .foregroundStyle(ReefTheme.Ink.secondary)
                        Image(systemName: hour.condition.symbol)
                            .font(.system(size: 13))
                            .foregroundStyle(accent)
                        Text(hour.temperatureText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ReefTheme.Ink.primary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func dayList(_ days: [DayForecast]) -> some View {
        VStack(spacing: 4) {
            ForEach(days) { day in
                HStack(spacing: 8) {
                    Text(Self.dayLabel(day.date))
                        .font(.system(size: 11))
                        .foregroundStyle(ReefTheme.Ink.primary)
                        .frame(width: 34, alignment: .leading)
                    Image(systemName: day.condition.symbol)
                        .font(.system(size: 12))
                        .foregroundStyle(accent)
                        .frame(width: 20)
                    Spacer(minLength: 0)
                    Text(day.lowText)
                        .foregroundStyle(ReefTheme.Ink.secondary)
                    Text(day.highText)
                        .foregroundStyle(ReefTheme.Ink.primary)
                }
                .font(.system(size: 11))
                .monospacedDigit()
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 4) {
            Image(systemName: "cloud.sun")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(ReefTheme.Ink.secondary)
            Text("Weather unavailable")
                .font(ReefTheme.Typography.caption)
                .foregroundStyle(ReefTheme.Ink.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// "Now" for the current hour, otherwise a short hour like "3PM".
    private static func hourLabel(_ date: Date) -> String {
        if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .hour) {
            return "Now"
        }
        return date.formatted(.dateTime.hour())
    }

    /// A short weekday like "Mon".
    private static func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }
}
