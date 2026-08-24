import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A render target in real pixels. Wallpapers are produced at exactly these
/// dimensions so iOS never has to rescale them.
public struct DeviceCanvas: Identifiable, Hashable, Sendable {

    public let id: String
    public let name: String
    public let detail: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    /// Native UIKit scale — 3 for Pro/Max/Plus phones, 2 for everything else.
    public let scale: CGFloat

    public init(id: String, name: String, detail: String,
                pixelWidth: Int, pixelHeight: Int, scale: CGFloat) {
        self.id = id
        self.name = name
        self.detail = detail
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.scale = scale
    }

    public var pixelSize: CGSize { CGSize(width: pixelWidth, height: pixelHeight) }

    /// The size the SwiftUI view is laid out at; multiplied back up by `scale`
    /// at render time to land on `pixelSize` exactly.
    public var pointSize: CGSize {
        CGSize(width: CGFloat(pixelWidth) / scale, height: CGFloat(pixelHeight) / scale)
    }

    public var aspectRatio: CGFloat { CGFloat(pixelWidth) / CGFloat(pixelHeight) }

    public var megapixels: Double {
        Double(pixelWidth * pixelHeight) / 1_000_000
    }

    public var resolutionLabel: String {
        "\(pixelWidth) × \(pixelHeight) px"
    }

    // Native panel resolutions, newest first.
    public static let presets: [DeviceCanvas] = [
        .init(id: "iphone-6.9", name: "iPhone 6.9″ Pro Max",
              detail: "16/17 Pro Max, 16 Plus", pixelWidth: 1320, pixelHeight: 2868, scale: 3),
        .init(id: "iphone-6.3", name: "iPhone 6.3″ Pro",
              detail: "16/17 Pro", pixelWidth: 1206, pixelHeight: 2622, scale: 3),
        .init(id: "iphone-6.7", name: "iPhone 6.7″",
              detail: "14/15 Pro Max, 15 Plus", pixelWidth: 1290, pixelHeight: 2796, scale: 3),
        .init(id: "iphone-6.1-pro", name: "iPhone 6.1″",
              detail: "14 Pro, 15, 16", pixelWidth: 1179, pixelHeight: 2556, scale: 3),
        .init(id: "iphone-6.1", name: "iPhone 6.1″ (older)",
              detail: "12, 13, 14", pixelWidth: 1170, pixelHeight: 2532, scale: 3),
        .init(id: "iphone-5.4", name: "iPhone mini",
              detail: "12 mini, 13 mini", pixelWidth: 1080, pixelHeight: 2340, scale: 3),
        .init(id: "iphone-6.5", name: "iPhone 6.5″",
              detail: "XS Max, 11 Pro Max", pixelWidth: 1242, pixelHeight: 2688, scale: 3),
        .init(id: "iphone-se", name: "iPhone SE",
              detail: "SE 2nd/3rd gen, 8", pixelWidth: 750, pixelHeight: 1334, scale: 2),
        .init(id: "ipad-pro-13", name: "iPad Pro 13″",
              detail: "M4 portrait", pixelWidth: 2064, pixelHeight: 2752, scale: 2),
        .init(id: "ipad-11", name: "iPad 11″",
              detail: "Air/Pro portrait", pixelWidth: 1668, pixelHeight: 2388, scale: 2)
    ]

    public static func preset(id: String?) -> DeviceCanvas? {
        guard let id else { return nil }
        return presets.first { $0.id == id }
    }

    /// The panel of the device the code is running on, read straight from
    /// `nativeBounds` so it is right on hardware that shipped after this build.
    public static var current: DeviceCanvas {
        #if canImport(UIKit) && !os(watchOS)
        let bounds = UIScreen.main.nativeBounds
        let scale = UIScreen.main.nativeScale
        let width = Int(min(bounds.width, bounds.height))
        let height = Int(max(bounds.width, bounds.height))
        if let match = presets.first(where: { $0.pixelWidth == width && $0.pixelHeight == height }) {
            return match
        }
        return DeviceCanvas(
            id: "native-\(width)x\(height)",
            name: "This device",
            detail: "Detected panel",
            pixelWidth: width,
            pixelHeight: height,
            scale: scale > 0 ? scale : 3
        )
        #else
        return presets[0]
        #endif
    }

    /// What `settings` resolves to: an explicit choice, or this device.
    public static func resolved(from settings: WallpaperSettings) -> DeviceCanvas {
        preset(id: settings.canvasID) ?? current
    }
}
