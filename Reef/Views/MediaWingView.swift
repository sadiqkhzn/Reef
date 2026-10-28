import AppKit
import SwiftUI

/// The resting media activity.
///
/// Album art sits on the leading side and a lively equalizer on the trailing
/// side, tinted with a color drawn from the art. Hovering the trailing side
/// turns the equalizer into a play/pause button over a slowly revolving glow;
/// clicking it toggles playback. While paused the bars fall quiet.
struct MediaWingView: View {
    let nowPlaying: NowPlaying
    @ObservedObject var media: NowPlayingController
    var height: CGFloat
    /// False while hopping screens, so the motion stops.
    var animating: Bool = true
    /// Reports when the pointer is over the trailing control, so the island
    /// knows not to open while a button is hovered.
    var onControlHover: (Bool) -> Void = { _ in }

    @State private var tint: Color = .white
    @State private var controlHovered = false

    private var coverSide: CGFloat { max(16, height - 7) }
    private var coverRadius: CGFloat { coverSide * 0.3 }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            cover
            Spacer(minLength: 10)
            control
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: refreshTint)
        .onChange(of: nowPlaying.artworkToken) { _ in refreshTint() }
    }

    // MARK: - Cover

    @ViewBuilder
    private var cover: some View {
        if let image = nowPlaying.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: coverSide, height: coverSide)
                .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .frame(width: coverSide, height: coverSide)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: coverSide * 0.42, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7)))
        }
    }

    // MARK: - Trailing control

    private var control: some View {
        ZStack {
            if controlHovered {
                revolvingGlow
                Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .transition(.opacity)
            } else {
                MediaEqualizer(tint: tint, active: animating && nowPlaying.isPlaying)
                    .transition(.opacity)
            }
        }
        .frame(width: 30, height: height)
        .contentShape(Rectangle())
        .onHover { hovering in
            controlHovered = hovering
            onControlHover(hovering)
        }
        .onTapGesture { media.playPause() }
        .animation(.easeInOut(duration: 0.18), value: controlHovered)
    }

    private var revolvingGlow: some View {
        TimelineView(.animation) { timeline in
            let angle = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 4) / 4 * 360
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            tint.opacity(0.0), tint.opacity(0.65),
                            tint.opacity(0.0), tint.opacity(0.0),
                        ],
                        center: .center))
                .frame(width: 26, height: 26)
                .blur(radius: 4)
                .rotationEffect(.degrees(angle))
        }
    }

    private func refreshTint() {
        tint = nowPlaying.artwork?.reefTint ?? .white
    }
}

/// A row of bars that bounce independently, so it reads as music rather than a
/// single synced wave. Tinted, and quiet (short and still) when inactive.
struct MediaEqualizer: View {
    var tint: Color
    var active: Bool
    var barCount: Int = 4

    var body: some View {
        if active {
            TimelineView(.animation) { timeline in
                bars(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            bars(time: 0, quiet: true)
        }
    }

    private func bars(time: TimeInterval, quiet: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(tint)
                    .frame(width: 3, height: quiet ? 3 : height(time: time, index: index))
            }
        }
        .frame(height: 16)
        .animation(.easeOut(duration: 0.12), value: quiet)
    }

    /// Each bar follows its own pair of waves at different rates, so they rise
    /// and fall out of step with each other.
    private func height(time: TimeInterval, index: Int) -> CGFloat {
        let seed = Double(index) * 7.13
        let a = sin(time * (3.1 + Double(index) * 0.9) + seed)
        let b = sin(time * (5.7 + Double(index) * 1.4) + seed * 1.7)
        let value = (a * 0.6 + b * 0.4) * 0.5 + 0.5
        return 3 + CGFloat(value) * 13
    }
}

extension NSImage {
    /// A vivid color drawn from the image, used to tint the equalizer. Averages
    /// the pixels, then lifts saturation and brightness so it reads on the dark
    /// island even when the art is muted.
    var reefTint: Color? {
        guard let tiff = tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let input = CIImage(bitmapImageRep: bitmap) else {
            return nil
        }

        let extent = input.extent
        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: input,
                kCIInputExtentKey: CIVector(cgRect: extent),
            ]),
            let output = filter.outputImage else {
            return nil
        }

        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB())

        let base = NSColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1)
        guard let hsb = base.usingColorSpace(.deviceRGB) else { return nil }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        hsb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

        let lifted = NSColor(
            hue: hue,
            saturation: max(0.55, saturation),
            brightness: max(0.8, brightness),
            alpha: 1)
        return Color(nsColor: lifted)
    }
}
