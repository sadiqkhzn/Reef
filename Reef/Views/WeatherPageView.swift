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
        ZStack {
            if let snapshot {
                // A corner glow of the current sky, not a full flood — keeps the
                // dark obsidian island while hinting the weather in the top-left.
                RadialGradient(
                    colors: [
                        (snapshot.condition.skyColors.first ?? accent).opacity(0.55),
                        .clear,
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 240)
                    .blur(radius: 24)
                    .ignoresSafeArea()
            }
            VStack(spacing: 0) {
                header
                    .frame(height: topInset)

                if let snapshot {
                    content(snapshot)
                } else {
                    empty
                }
            }
            // Keep the content above the nav bar; the gradient still fills behind it.
            .padding(.bottom, NotchState.tabBarHeight)
        }
    }

    /// Top clearance: the full header height to clear the notch in the attached
    /// style, or a small inset when floating so there is no dead space.
    private var topInset: CGFloat {
        notchWidth > 0 ? headerHeight : ReefTheme.Spacing.s
    }

    private var header: some View {
        // The bottom tab bar already labels this page, so the header is just the
        // top clearance.
        HStack(spacing: 0) {
            Spacer(minLength: notchWidth + ReefTheme.Spacing.l)
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
    }

    private func content(_ snapshot: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: ReefTheme.Spacing.s) {
            // Top row: current conditions on the left, the hourly slider on the
            // right — each taking about half the width.
            HStack(alignment: .top, spacing: ReefTheme.Spacing.s) {
                current(snapshot)
                    .frame(maxWidth: .infinity)
                if let hours = forecast?.upcomingHours(), !hours.isEmpty {
                    hourStrip(hours)
                        .frame(maxWidth: .infinity)
                }
            }
            // The days scroll below, with the same slider fades top and bottom.
            if let days = forecast?.upcomingDays(), !days.isEmpty {
                ScrollView(showsIndicators: false) {
                    dayList(days)
                        // Inset so the first and last rows sit past the fades.
                        .padding(.vertical, 12)
                }
                .mask(
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: 12)
                        Rectangle().fill(.black)
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 12)
                    })
            }
        }
        .padding(.horizontal, ReefTheme.Radius.islandInset)
        .padding(.top, 2)
    }

    private func current(_ snapshot: WeatherSnapshot) -> some View {
        HStack(spacing: ReefTheme.Spacing.s) {
            Image(systemName: snapshot.condition.symbol)
                .font(.system(size: 22))
                .symbolRenderingMode(.multicolor)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(snapshot.condition.tint.opacity(0.28))
                        .blur(radius: 2))
            VStack(alignment: .leading, spacing: 0) {
                Text(snapshot.temperatureText)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(ReefTheme.Ink.primary)
                Text(snapshot.condition.label)
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(ReefTheme.Ink.secondary)
            }
            Spacer(minLength: 0)
            if let high = snapshot.highText, let low = snapshot.lowText {
                HStack(spacing: ReefTheme.Spacing.s) {
                    Label(high, systemImage: "arrow.up")
                        .foregroundStyle(ReefTheme.Ink.primary)
                    Label(low, systemImage: "arrow.down")
                        .foregroundStyle(ReefTheme.Ink.secondary)
                }
                .labelStyle(.titleAndIcon)
                .font(ReefTheme.Typography.caption)
                .monospacedDigit()
            }
        }
        .islandCard(padding: ReefTheme.Spacing.s)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func hourStrip(_ hours: [HourForecast]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(hours) { hour in
                    VStack(spacing: 3) {
                        Text(Self.hourLabel(hour.date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(ReefTheme.Ink.secondary)
                        Image(systemName: hour.condition.symbol)
                            .font(.system(size: 14))
                            .symbolRenderingMode(.multicolor)
                            .frame(height: 16)
                        Text(hour.temperatureText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(ReefTheme.Ink.primary)
                    }
                    .padding(.vertical, 6)
                    .frame(width: 40)
                    .background(
                        RoundedRectangle(cornerRadius: ReefTheme.Radius.control, style: .continuous)
                            .fill(ReefTheme.Ink.fill))
                }
            }
            // Inset by the fade width so the first and last cards sit past the
            // fade zones (fully visible); only mid-scroll cards dissolve.
            .padding(.horizontal, 16)
            .padding(.vertical, 1)
        }
        // Soft fades at the left and right edges so the strip reads as a slider,
        // dissolving as hours scroll off either side.
        .mask(
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 16)
                Rectangle().fill(.black)
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 16)
            })
    }

    private func dayList(_ days: [DayForecast]) -> some View {
        VStack(spacing: 3) {
            ForEach(days) { day in
                HStack(spacing: ReefTheme.Spacing.s) {
                    Text(Self.dayLabel(day.date))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ReefTheme.Ink.primary)
                        .frame(width: 34, alignment: .leading)
                    Image(systemName: day.condition.symbol)
                        .font(.system(size: 12))
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 20)
                    Spacer(minLength: 0)
                    Text(day.lowText)
                        .foregroundStyle(ReefTheme.Ink.secondary)
                    Text(day.highText)
                        .foregroundStyle(ReefTheme.Ink.primary)
                }
                .font(.system(size: 11, design: .rounded))
                .monospacedDigit()
                .padding(.horizontal, ReefTheme.Spacing.s)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: ReefTheme.Radius.control, style: .continuous)
                        .fill(ReefTheme.Ink.fill))
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
