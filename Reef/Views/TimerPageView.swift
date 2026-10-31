import SwiftUI

/// The timer page of the open island.
///
/// With no timer running it offers a row of presets to start one. While a timer
/// is going it shows a large ring with the time left and controls to pause,
/// resume, add a minute, or cancel.
struct TimerPageView: View {
    @ObservedObject var timer: TimerController
    var accent: Color
    var headerHeight: CGFloat
    var notchWidth: CGFloat
    /// Leave the open island (back to home).
    var onClose: () -> Void

    /// Preset lengths in minutes.
    private let presets: [Int] = [1, 3, 5, 10, 15, 25]

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: headerHeight)

            if timer.isActive {
                running
            } else {
                presetGrid
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button(action: onClose) {
                Label("Timer", systemImage: "chevron.left")
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
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accent.opacity(0.14)))
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
        .padding(.vertical, 8)
    }

    // MARK: - Running

    private var ringTint: Color { timer.isFinished ? ReefTheme.Status.warning : accent }

    private var running: some View {
        HStack(spacing: ReefTheme.Spacing.l) {
            ring
            VStack(alignment: .leading, spacing: 6) {
                Text(timer.isFinished ? "Time's up" : TimerController.label(timer.remaining))
                    .font(.system(size: 22, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(ReefTheme.Ink.primary)
                    .contentTransition(.numericText())
                controls
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ReefTheme.Spacing.l)
        .padding(.vertical, 8)
        .frame(maxHeight: .infinity)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(ringTint.opacity(0.22), lineWidth: 5)
            Circle()
                .trim(from: 0, to: timer.isFinished ? 1 : 1 - timer.progress)
                .stroke(ringTint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.2), value: timer.progress)
            Image(systemName: timer.isFinished ? "bell.fill" : "timer")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ringTint)
                .symbolEffect(.pulse, options: .repeating, isActive: timer.isFinished)
        }
        .frame(width: 54, height: 54)
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
}
