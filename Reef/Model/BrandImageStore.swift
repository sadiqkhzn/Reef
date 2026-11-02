import AppKit

/// How large the brand image renders within the resting island band.
enum BrandImageSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    /// Fraction of the available band height the logo fills.
    var scale: CGFloat {
        switch self {
        case .small: return 0.6
        case .medium: return 0.8
        case .large: return 1.0
        }
    }
}

/// Stores the user's brand image on disk (Application Support), downscaled and
/// re-encoded to PNG so the resting island can draw it cheaply. The file is the
/// source of truth; settings only remember that it is on.
enum BrandImageStore {
    private static var directory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Reef", isDirectory: true)
    }

    static var fileURL: URL { directory.appendingPathComponent("brand-image.png") }

    static func load() -> NSImage? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return NSImage(contentsOf: fileURL)
    }

    /// Read a user-chosen image, downscale it, and save it as PNG. Returns the
    /// stored image, or nil when the file can't be read or encoded.
    @discardableResult
    static func importImage(from url: URL, maxDimension: CGFloat = 512) -> NSImage? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let image = NSImage(contentsOf: url) else { return nil }
        return store(image, maxDimension: maxDimension)
    }

    @discardableResult
    static func store(_ image: NSImage, maxDimension: CGFloat = 512) -> NSImage? {
        guard let png = pngData(image, maxDimension: maxDimension) else { return nil }
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try png.write(to: fileURL, options: .atomic)
            return NSImage(data: png)
        } catch {
            return nil
        }
    }

    static func remove() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Flatten the image to a PNG whose long edge is at most `maxDimension`,
    /// preserving aspect ratio and transparency.
    private static func pngData(_ image: NSImage, maxDimension: CGFloat) -> Data? {
        let pixelSize = bitmapPixelSize(image) ?? image.size
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }

        let longEdge = max(pixelSize.width, pixelSize.height)
        let scale = longEdge > maxDimension ? maxDimension / longEdge : 1
        let target = CGSize(
            width: max(1, (pixelSize.width * scale).rounded()),
            height: max(1, (pixelSize.height * scale).rounded()))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(target.width),
            pixelsHigh: Int(target.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0) else { return nil }
        rep.size = target

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(
            in: NSRect(origin: .zero, size: target),
            from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }

    private static func bitmapPixelSize(_ image: NSImage) -> CGSize? {
        for rep in image.representations where rep.pixelsWide > 0 {
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return nil
    }
}
