import SwiftUI

/// The timer page of the open island, in a wide two-pane layout.
///
/// Left pane: a self-contained card with a Timer/Stopwatch toggle on top and,
/// below it, the running timer, the stopwatch, or — when idle — the chosen
/// length with steppers and a Start button. Right pane: a scrolling list of
/// named presets that start a timer at a tap.
struct TimerPageView: View {
    @ObservedObject var timer: TimerController
    @ObservedObject var stopwatch: StopwatchController
    var accent: Color
    var headerHeight: CGFloat
    var notchWidth: CGFloat
    /// Leave the open island (back to home).
    var onClose: () -> Void

    private enum Mode { case timer, stopwatch }
    @State private var mode: Mode = .timer
    /// The length the idle left pane will start, in minutes.
    @State private var selectedMinutes: Int = 25

    /// Named presets for the right pane.
    private let presets: [(name: String, minutes: Int)] = [
        ("Focus", 25),
        ("Short Break", 5),
        ("Long Break", 15),
        ("Deep Work", 50),
        ("Quick", 1),
        ("Tea", 3),
    ]

    /// Top clearance: the full header height to clear the notch in the attached
    /// style, or a small inset when floating so there is no dead space.
    private var topInset: CGFloat {
        notchWidth > 0 ? headerHeight : ReefTheme.Spacing.s
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)
            panes
        }
        .onAppear {
            // Land on whichever is already going, favoring a running timer.
            if timer.isActive {
                mode = .timer
            } else if stopwatch.isActive {
                mode = .stopwatch
            }
        }
    }

    // MARK: - Panes

    private var panes: some View {
        HStack(alignment: .top, spacing: ReefTheme.Spacing.s) {
            leftCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Match the list's reserved bottom room so the card's box bottom
                // lines up with the last preset row, both clear of the nav bar.
                .padding(.bottom, 8)
            presetList
                .frame(maxHeight: .infinity)
                .frame(width: 196)
        }
        .padding(.horizontal, ReefTheme.Spacing.s)
        .padding(.bottom, 8)
    }

    /// The fixed left card: the mode toggle on top and the control below it,
    /// centered in whatever room is left.
    private var leftCard: some View {
        VStack(spacing: 0) {
            modeToggle
            // Bias the control slightly below center so it lines up lower, closer
            // to the last preset row on the right. A fixed height keeps Timer and
            // Stopwatch the same size.
            Spacer(minLength: 0)
            Spacer(minLength: 0)
            control
                .frame(height: 72)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .padding(ReefTheme.Spacing.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .islandCard(padding: 0)
    }

    @ViewBuilder
    private var control: some View {
        if mode == .stopwatch {
            stopwatchControl
        } else if timer.isActive {
            running
        } else {
            idle
        }
    }

    // MARK: - Idle

    private var idle: some View {
        VStack(spacing: ReefTheme.Spacing.s) {
            HStack(spacing: ReefTheme.Spacing.m) {
                stepper("minus") { selectedMinutes = max(1, selectedMinutes - 1) }
                Text(TimerController.label(TimeInterval(selectedMinutes * 60)))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ReefTheme.Ink.primary)
                    .contentTransition(.numericText())
                    .frame(minWidth: 82)
                stepper("plus") { selectedMinutes = min(180, selectedMinutes + 1) }
            }
            Button {
                timer.start(TimeInterval(selectedMinutes * 60))
            } label: {
                Label("Start", systemImage: "play.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, ReefTheme.Spacing.l)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(accent))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func stepper(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 22)
                .background(Capsule().fill(accent.opacity(0.16)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Running

    private var ringTint: Color { timer.isFinished ? ReefTheme.Status.warning : accent }

    private var running: some View {
        HStack(spacing: ReefTheme.Spacing.m) {
            RingGauge(
                progress: timer.isFinished ? 1 : 1 - timer.progress,
                tint: ringTint,
                lineWidth: 5)
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: timer.isFinished ? "bell.fill" : "timer")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(ringTint)
                        .symbolEffect(.pulse, options: .repeating, isActive: timer.isFinished)
                }
            VStack(alignment: .leading, spacing: 6) {
                Text(timer.isFinished ? "Time's up" : TimerController.label(timer.remaining))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ReefTheme.Ink.primary)
                    .contentTransition(.numericText())
                controls
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            if timer.isFinished {
                pillButton("Done", symbol: "checkmark", filled: true) { timer.cancel() }
            } else {
                if timer.isRunning {
                    iconButton("pause.fill") { timer.pause() }
                } else {
                    iconButton("play.fill") { timer.resume() }
                }
                iconButton("plus") { timer.addMinute() }
                iconButton("xmark") { timer.cancel() }
            }
        }
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 26, height: 22)
                .background(Capsule().fill(accent.opacity(0.16)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func pillButton(
        _ title: String, symbol: String, filled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .font(ReefTheme.Typography.caption)
                .foregroundStyle(filled ? .white : accent)
                .padding(.horizontal, ReefTheme.Spacing.s)
                .padding(.vertical, 4)
                .background(Capsule().fill(filled ? accent : accent.opacity(0.16)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stopwatch

    private var stopwatchControl: some View {
        VStack(spacing: ReefTheme.Spacing.s) {
            TimelineView(.animation(minimumInterval: 0.05, paused: !stopwatch.isRunning)) { _ in
                Text(StopwatchController.label(stopwatch.elapsed))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ReefTheme.Ink.primary)
            }
            HStack(spacing: ReefTheme.Spacing.s) {
                if stopwatch.isRunning {
                    iconButton("pause.fill") { stopwatch.pause() }
                } else {
                    iconButton("play.fill") { stopwatch.start() }
                }
                iconButton("arrow.counterclockwise") { stopwatch.reset() }
            }
        }
    }

    // MARK: - Mode toggle

    private var modeToggle: some View {
        HStack(spacing: 2) {
            segment("Timer", on: mode == .timer) { mode = .timer }
            segment("Stopwatch", on: mode == .stopwatch) { mode = .stopwatch }
        }
        .padding(2)
        .background(Capsule().fill(.white.opacity(0.06)))
    }

    private func segment(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(on ? .white : ReefTheme.Ink.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(on ? accent : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Presets

    private var presetList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ReefTheme.Spacing.s) {
                ForEach(presets, id: \.name) { preset in
                    Button {
                        timer.start(TimeInterval(preset.minutes * 60))
                        mode = .timer
                    } label: {
                        presetRow(preset)
                    }
                    .buttonStyle(.plain)
                }
            }
            // Room below the last row so, scrolled to the end, that row sits
            // above the fade (only the empty space dissolves) and is fully clear.
            .padding(.bottom, 8)
        }
        // A soft, fixed-height fade along the bottom edge so mid-scroll rows
        // dissolve rather than cutting off hard, hinting there is more to scroll.
        .mask(
            VStack(spacing: 0) {
                Rectangle().fill(.black)
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 8)
            })
    }

    private func presetRow(_ preset: (name: String, minutes: Int)) -> some View {
        HStack(spacing: ReefTheme.Spacing.s) {
            VStack(alignment: .leading, spacing: 1) {
                Text(preset.name)
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(ReefTheme.Ink.primary)
                Text(String(format: "%02d:00", preset.minutes))
                    .font(.system(size: 10, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ReefTheme.Ink.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "play.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(accent.opacity(0.16)))
        }
        .padding(.horizontal, ReefTheme.Spacing.m)
        .padding(.vertical, ReefTheme.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: ReefTheme.Radius.control, style: .continuous)
                .fill(ReefTheme.Ink.fill))
        .contentShape(Rectangle())
    }
}
