import SwiftUI

/// The timer page of the open island.
///
/// With no timer running it offers a row of presets to start one. While a timer
/// is going it shows a large ring with the time left and controls to pause,
/// resume, add a minute, or cancel.
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

    /// Color of the page's background wash: warning while a finished timer rings,
    /// the accent otherwise.
    private var washTint: Color {
        mode == .timer && timer.isFinished ? ReefTheme.Status.warning : accent
    }

    /// Preset lengths in minutes.
    private let presets: [Int] = [1, 3, 5, 10, 15, 25]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [washTint.opacity(0.3), washTint.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header
                    .frame(height: headerHeight)

                if mode == .stopwatch {
                    stopwatchView
                } else if timer.isActive {
                    running
                } else {
                    presetGrid
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

    private var header: some View {
        HStack(spacing: ReefTheme.Spacing.s) {
            Text("Timer")
                .font(ReefTheme.Typography.caption)
                .foregroundStyle(accent)
                .padding(.horizontal, ReefTheme.Spacing.s)
                .padding(.vertical, 3)
                .background(Capsule().fill(accent.opacity(0.18)))
            modeToggle
            Spacer(minLength: notchWidth + ReefTheme.Spacing.s)
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
    }

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

    // MARK: - Presets

    private var presetGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(presets, id: \.self) { minutes in
                Button {
                    timer.start(TimeInterval(minutes) * 60)
                } label: {
                    VStack(spacing: 1) {
                        Text("\(minutes)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(ReefTheme.Ink.primary)
                        Text("min")
                            .font(.system(size: 9))
                            .foregroundStyle(ReefTheme.Ink.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: ReefTheme.Radius.control, style: .continuous)
                            .fill(accent.opacity(0.16)))
                    .overlay(
                        RoundedRectangle(cornerRadius: ReefTheme.Radius.control, style: .continuous)
                            .strokeBorder(accent.opacity(0.22), lineWidth: 0.5))
                    .contentShape(RoundedRectangle(cornerRadius: ReefTheme.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ReefTheme.Radius.islandInset)
        .padding(.vertical, 8)
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
        .islandCard(padding: ReefTheme.Spacing.l)
        .padding(.horizontal, ReefTheme.Radius.islandInset)
        .padding(.bottom, ReefTheme.Radius.islandInset)
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
        .islandCard(padding: ReefTheme.Spacing.l)
        .padding(.horizontal, ReefTheme.Radius.islandInset)
        .padding(.bottom, ReefTheme.Radius.islandInset)
    }
}
