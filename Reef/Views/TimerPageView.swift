import SwiftUI

/// The timer page of the open island, in a wide two-pane layout.
///
/// Left pane: the running timer (a ring with the time left and controls) or,
/// when idle, a large time with steppers and a Start button. Right pane: a list
/// of named presets that start a timer at a tap. A segmented control at the top
/// of the left pane switches to a full-width stopwatch.
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

    /// Color of the page's background wash: warning while a finished timer rings,
    /// the accent otherwise.
    private var washTint: Color {
        mode == .timer && timer.isFinished ? ReefTheme.Status.warning : accent
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [washTint.opacity(0.3), washTint.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Color.clear.frame(height: topInset)
                if mode == .stopwatch {
                    stopwatchPane
                } else {
                    timerPanes
                }
            }
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

    private var timerPanes: some View {
        HStack(alignment: .top, spacing: ReefTheme.Spacing.s) {
            VStack(spacing: ReefTheme.Spacing.s) {
                modeToggle
                    .frame(maxWidth: .infinity, alignment: .leading)
                leftControl
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            presetList
                .frame(width: 208)
        }
        .padding(.horizontal, ReefTheme.Spacing.s)
        .padding(.bottom, ReefTheme.Spacing.s)
    }

    @ViewBuilder
    private var leftControl: some View {
        if timer.isActive {
            running
        } else {
            idleControl
        }
    }

    /// Idle: the chosen length, steppers to adjust it, and Start.
    private var idleControl: some View {
        VStack(spacing: ReefTheme.Spacing.m) {
            Spacer(minLength: 0)
            Text(TimerController.label(TimeInterval(selectedMinutes * 60)))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ReefTheme.Ink.primary)
                .contentTransition(.numericText())
            HStack(spacing: ReefTheme.Spacing.m) {
                stepper("minus") { selectedMinutes = max(1, selectedMinutes - 1) }
                stepper("plus") { selectedMinutes = min(180, selectedMinutes + 1) }
            }
            Button {
                timer.start(TimeInterval(selectedMinutes * 60))
            } label: {
                Label("Start", systemImage: "play.fill")
                    .labelStyle(.titleAndIcon)
                    .font(ReefTheme.Typography.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, ReefTheme.Spacing.l)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(accent))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .islandCard(padding: ReefTheme.Spacing.m)
    }

    private func stepper(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 32, height: 28)
                .background(Capsule().fill(accent.opacity(0.16)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var presetList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ReefTheme.Spacing.s) {
                ForEach(presets, id: \.name) { preset in
                    Button {
                        timer.start(TimeInterval(preset.minutes * 60))
                    } label: {
                        presetRow(preset)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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

    // MARK: - Mode toggle

    /// A small segmented control to switch between the timer and the stopwatch.
    private var modeToggle: some View {
        HStack(spacing: 2) {
            segment("Timer", on: mode == .timer) { mode = .timer }
            segment("Stopwatch", on: mode == .stopwatch) { mode = .stopwatch }
        }
        .padding(2)
        .background(Capsule().fill(accent.opacity(0.1)))
    }

    private func segment(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(on ? .white : ReefTheme.Ink.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(on ? accent : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Running

    private var ringTint: Color { timer.isFinished ? ReefTheme.Status.warning : accent }

    private var running: some View {
        HStack(spacing: ReefTheme.Spacing.l) {
            ring
            VStack(alignment: .leading, spacing: ReefTheme.Spacing.s) {
                Text(timer.isFinished ? "Time's up" : TimerController.label(timer.remaining))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ReefTheme.Ink.primary)
                    .contentTransition(.numericText())
                controls
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .islandCard(padding: ReefTheme.Spacing.l)
    }

    private var ring: some View {
        RingGauge(
            progress: timer.isFinished ? 1 : 1 - timer.progress,
            tint: ringTint,
            lineWidth: 5)
            .frame(width: 58, height: 58)
            .overlay {
                Image(systemName: timer.isFinished ? "bell.fill" : "timer")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ringTint)
                    .symbolEffect(.pulse, options: .repeating, isActive: timer.isFinished)
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

    private var stopwatchPane: some View {
        VStack(spacing: ReefTheme.Spacing.s) {
            modeToggle
                .frame(maxWidth: .infinity, alignment: .leading)
            stopwatchView
        }
        .padding(.horizontal, ReefTheme.Spacing.s)
        .padding(.bottom, ReefTheme.Spacing.s)
    }

    private var stopwatchView: some View {
        HStack(spacing: ReefTheme.Spacing.l) {
            Image(systemName: "stopwatch")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(accent)
                .symbolEffect(.pulse, options: .repeating, isActive: stopwatch.isRunning)
                .frame(width: 34)
            TimelineView(.animation(minimumInterval: 0.05, paused: !stopwatch.isRunning)) { _ in
                Text(StopwatchController.label(stopwatch.elapsed))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ReefTheme.Ink.primary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                if stopwatch.isRunning {
                    iconButton("pause.fill") { stopwatch.pause() }
                } else {
                    iconButton("play.fill") { stopwatch.start() }
                }
                iconButton("arrow.counterclockwise") { stopwatch.reset() }
            }
        }
        .frame(maxWidth: .infinity)
        .islandCard(padding: ReefTheme.Spacing.l)
    }
}
