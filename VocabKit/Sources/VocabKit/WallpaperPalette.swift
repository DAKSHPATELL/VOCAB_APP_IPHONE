import SwiftUI

/// Which visual language the wallpaper is drawn in.
public enum WallpaperTheme: String, Codable, CaseIterable, Sendable {
    /// Flat true black, restrained greys, small type. Nothing glows.
    case graphite
    /// Warm near-blacks with ember blooms and a gradient-filled headword.
    case ember

    public var title: String {
        switch self {
        case .graphite: "Graphite"
        case .ember: "Ember"
        }
    }

    public var subtitle: String {
        switch self {
        case .graphite: "Pure black, grey type, quiet"
        case .ember: "Dark ground lit red and orange"
        }
    }
}

/// Every colour and size ratio the wallpaper needs, so the canvas never
/// branches on the theme itself — it just draws whatever palette it is handed.
public struct WallpaperPalette: Sendable {

    public let ground: Color
    /// `nil` means a flat fill with no gradient at all.
    public let groundGradient: [Color]?
    public let usesEmberField: Bool

    public let word: Color
    public let wordGradient: [Color]?
    public let article: Color
    public let translation: Color
    public let caption: Color
    public let captionAccent: Color
    public let meta: Color
    public let example: Color
    public let exampleHighlight: Color
    public let hairline: Color

    /// Multiplies every type size, so "smaller" is one number rather than
    /// fifteen edits.
    public let typeScale: CGFloat
    /// 0 disables the glow behind the headword entirely.
    public let glow: CGFloat

    /// True black, mid greys, small restrained type. On an OLED panel the
    /// background is genuinely off rather than merely dark.
    public static let graphite = WallpaperPalette(
        ground: Color(hex: 0x00_00_00),
        groundGradient: nil,
        usesEmberField: false,
        word: Color(hex: 0xD8_D6_D3),
        wordGradient: nil,
        article: Color(hex: 0x6B_69_67),
        translation: Color(hex: 0x9B_98_95),
        caption: Color(hex: 0x55_53_51),
        captionAccent: Color(hex: 0x7E_7B_78),
        meta: Color(hex: 0x63_61_5F),
        example: Color(hex: 0x8B_88_85),
        exampleHighlight: Color(hex: 0xCB_C8_C5),
        hairline: Color(hex: 0x24_23_22),
        typeScale: 0.62,
        glow: 0
    )

    public static let ember = WallpaperPalette(
        ground: Ember.void,
        groundGradient: [Ember.pitch, Ember.void, Ember.ash, Ember.soot],
        usesEmberField: true,
        word: Ember.orange,
        wordGradient: [Ember.gold, Ember.orange, Ember.ember, Ember.crimson],
        article: Ember.flame,
        translation: Ember.bone.opacity(0.88),
        caption: Ember.smoke,
        captionAccent: Ember.flame,
        meta: Ember.smoke.opacity(0.85),
        example: Ember.bone.opacity(0.82),
        exampleHighlight: Ember.flame,
        hairline: Ember.ember.opacity(0.5),
        typeScale: 1.0,
        glow: 1.0
    )

    public static func resolved(_ theme: WallpaperTheme) -> WallpaperPalette {
        switch theme {
        case .graphite: .graphite
        case .ember: .ember
        }
    }

    /// The ember theme colour-codes gender; graphite deliberately does not,
    /// because a single restrained grey is the whole point of it.
    public func accent(for entry: VocabEntry, theme: WallpaperTheme) -> Color {
        theme == .ember ? Ember.accent(for: entry) : captionAccent
    }
}
