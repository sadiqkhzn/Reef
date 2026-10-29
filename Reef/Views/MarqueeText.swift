import SwiftUI

/// One line of text that scrolls sideways when it is too wide to fit, and sits
/// centered when it fits. Used for the resume announcement and long track names.
struct MarqueeText: View {
    let text: String
    var color: Color = .white
    var font: Font = .system(size: 12, weight: .semibold)
    /// Scroll speed in points per second.
    var speed: CGFloat = 34
    /// Gap between the end of the text and the start of its repeat.
    var gap: CGFloat = 40

    @State private var textWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let overflow = textWidth > geo.size.width + 1

            Group {
                if overflow {
                    TimelineView(.animation) { timeline in
                        let period = Double(textWidth + gap) / Double(max(1, speed))
                        let progress = timeline.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: period) / period
                        HStack(spacing: gap) {
                            label
                            label
                        }
                        .offset(x: -CGFloat(progress) * (textWidth + gap))
                    }
                } else {
                    label.frame(width: geo.size.width, alignment: .center)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
        .clipped()
        .background(measurer)
    }

    private var label: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
    }

    /// Invisible copy used only to measure the text width.
    private var measurer: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize()
            .opacity(0)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { textWidth = proxy.size.width }
                        .onChange(of: text) { _ in textWidth = proxy.size.width }
                })
    }
}
