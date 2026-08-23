import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Rasterises `WallpaperCanvas` at exact device pixel dimensions.
///
/// `ImageRenderer` lays the view out in points and multiplies by `scale`, so
/// the output lands on `canvas.pixelSize` to the pixel — no resampling, no soft
/// edges, no letterboxing when iOS applies it as a wallpaper.
@MainActor
public enum WallpaperRenderer {

    public enum RenderError: Error, LocalizedError {
        case rasterisationFailed
        case encodingFailed

        public var errorDescription: String? {
            switch self {
            case .rasterisationFailed: "The wallpaper could not be drawn."
            case .encodingFailed: "The wallpaper could not be encoded as PNG."
            }
        }
    }

    #if canImport(UIKit)
    public static func image(
        entry: VocabEntry,
        hourIndex: Int,
        canvas: DeviceCanvas,
        settings: WallpaperSettings
    ) throws -> UIImage {
        // Supersampling draws at 2× and lets Core Graphics downsample on the
        // way into the PNG: slower, but noticeably crisper serif edges.
        let multiplier: CGFloat = settings.supersample ? 2 : 1

        let view = WallpaperCanvas(
            entry: entry,
            hourIndex: hourIndex,
            size: canvas.pointSize,
            settings: settings
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = canvas.scale * multiplier
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(canvas.pointSize)

        guard let rendered = renderer.uiImage else { throw RenderError.rasterisationFailed }
        guard multiplier > 1 else { return rendered }
        return downsample(rendered, to: canvas.pixelSize) ?? rendered
    }

    public static func pngData(
        entry: VocabEntry,
        hourIndex: Int,
        canvas: DeviceCanvas,
        settings: WallpaperSettings
    ) throws -> Data {
        let image = try image(
            entry: entry, hourIndex: hourIndex, canvas: canvas, settings: settings
        )
        guard let data = image.pngData() else { throw RenderError.encodingFailed }
        return data
    }

    /// PNG is the default because the design is flat gradients and type, where
    /// JPEG banding is visible. HEIC is offered for people exporting a week at a
    /// time who care about the storage.
    public static func heicData(
        entry: VocabEntry,
        hourIndex: Int,
        canvas: DeviceCanvas,
        settings: WallpaperSettings,
        quality: CGFloat = 0.95
    ) throws -> Data {
        let image = try image(
            entry: entry, hourIndex: hourIndex, canvas: canvas, settings: settings
        )
        guard let data = image.heicData(quality: quality) else {
            throw RenderError.encodingFailed
        }
        return data
    }

    private static func downsample(_ image: UIImage, to pixelSize: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
        }
    }
    #endif
}

#if canImport(UIKit)
import ImageIO
import UniformTypeIdentifiers

extension UIImage {
    func heicData(quality: CGFloat) -> Data? {
        guard let cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.heic.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination, cgImage,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
#endif
