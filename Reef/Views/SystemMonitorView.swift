import SwiftUI

/// The system-monitor pane: a CPU hero with a live sparkline on the left, and
/// memory + network wells stacked on the right.
struct SystemMonitorView: View {
    @ObservedObject var model: SystemMonitorModel
    var accent: Color
    var headerHeight: CGFloat
    var notchWidth: CGFloat
    /// Leave the open island (back to home).
    var onClose: () -> Void

    private var topInset: CGFloat {
        notchWidth > 0 ? headerHeight : ReefTheme.Spacing.s
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)
            HStack(alignment: .top, spacing: ReefTheme.Spacing.s) {
                cpuWell
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: ReefTheme.Spacing.s) {
                    memoryWell
                    networkWell
                }
                .frame(width: 178)
            }
            .padding(.horizontal, ReefTheme.Spacing.s)
            .padding(.bottom, 12)
        }
    }

    // MARK: - CPU

    private var cpuWell: some View {
        VStack(alignment: .leading, spacing: 2) {
            metricHeader("CPU LOAD")
            Text("\(Int((model.cpu * 100).rounded()))%")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ReefTheme.Ink.primary)
            sparkline
                .frame(maxHeight: .infinity)
            if model.gpuAvailable {
                gpuRow
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .islandCard(padding: ReefTheme.Spacing.m)
    }

    /// A slim GPU utilization bar tucked under the CPU sparkline.
    private var gpuRow: some View {
        HStack(spacing: ReefTheme.Spacing.s) {
            metricHeader("GPU")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(accent.opacity(0.7))
                        .frame(width: geo.size.width * CGFloat(min(1, model.gpu)))
                }
            }
            .frame(height: 4)
            Text("\(Int((model.gpu * 100).rounded()))%")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ReefTheme.Ink.secondary)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.top, 2)
    }

    private var sparkline: some View {
        GeometryReader { geo in
            let values = model.cpuHistory
            let line = path(values, in: geo.size)
            ZStack {
                line
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.28), .clear],
                            startPoint: .top, endPoint: .bottom),
                        style: .init())
                stroke(values, in: geo.size)
                    .stroke(accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }

    /// Closed path (down to the baseline) for the gradient fill.
    private func path(_ values: [Double], in size: CGSize) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let stepX = size.width / CGFloat(values.count - 1)
        path.move(to: CGPoint(x: 0, y: size.height))
        for (index, value) in values.enumerated() {
            path.addLine(to: CGPoint(x: CGFloat(index) * stepX, y: size.height * (1 - CGFloat(value))))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        return path
    }

    private func stroke(_ values: [Double], in size: CGSize) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let stepX = size.width / CGFloat(values.count - 1)
        for (index, value) in values.enumerated() {
            let point = CGPoint(x: CGFloat(index) * stepX, y: size.height * (1 - CGFloat(value)))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    // MARK: - Memory

    private var memoryWell: some View {
        let fraction = model.memTotal > 0 ? model.memUsed / model.memTotal : 0
        return VStack(alignment: .leading, spacing: 4) {
            metricHeader("MEMORY")
            Text("\(SystemMonitorModel.formatBytes(model.memUsed)) / \(SystemMonitorModel.formatBytes(model.memTotal))")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ReefTheme.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(fraction > 0.85 ? ReefTheme.Status.warning : accent)
                        .frame(width: geo.size.width * CGFloat(min(1, fraction)))
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .islandCard(padding: ReefTheme.Spacing.m)
    }

    // MARK: - Network

    private var networkWell: some View {
        HStack(spacing: ReefTheme.Spacing.m) {
            rate("arrow.down", model.netDown, .cyan)
            rate("arrow.up", model.netUp, .purple)
        }
        .frame(maxWidth: .infinity)
        .islandCard(padding: ReefTheme.Spacing.m)
    }

    private func rate(_ symbol: String, _ value: Double, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
            Text(SystemMonitorModel.formatRate(value))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(ReefTheme.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(ReefTheme.Ink.tertiary)
    }
}
