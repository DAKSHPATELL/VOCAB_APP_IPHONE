import Foundation

/// Everything the renderer needs, shared verbatim between the app and the
/// widget extension through the App Group container.
public struct WallpaperSettings: Codable, Equatable, Sendable {

    public var levels: Set<VocabEntry.Level>
    /// Empty means "no category filter".
    public var categories: Set<String>
    /// Empty means "every part of speech".
    public var partsOfSpeech: Set<VocabEntry.PartOfSpeech>

    public var theme: WallpaperTheme
    public var layout: WallpaperLayout
    public var showTranslation: Bool
    public var showExample: Bool
    public var showExampleTranslation: Bool
    public var showInflection: Bool
    public var showHourStamp: Bool

    /// 0…1, drives how far the ember glows bleed into the frame.
    public var emberIntensity: Double
    /// 0…1, analogue film grain. 0 turns it off.
    public var grain: Double
    public var vignette: Double

    /// Reshuffling the deck is a seed change — nothing else has to move.
    public var seed: UInt64

    public var canvasID: String?
    /// Renders at 2× the pixel target and downsamples: slower, visibly cleaner
    /// text edges on very large canvases.
    public var supersample: Bool

    public static let `default` = WallpaperSettings(
        levels: [.a1, .a2, .b1, .b2],
        categories: [],
        partsOfSpeech: [],
        theme: .graphite,
        layout: .lockScreen,
        showTranslation: true,
        showExample: true,
        showExampleTranslation: true,
        showInflection: true,
        showHourStamp: true,
        emberIntensity: 0.55,
        grain: 0.10,
        vignette: 0.0,
        seed: 0x5645_524E_4143_4B54,
        canvasID: nil,
        supersample: false
    )

    public init(
        levels: Set<VocabEntry.Level>,
        categories: Set<String>,
        partsOfSpeech: Set<VocabEntry.PartOfSpeech>,
        theme: WallpaperTheme,
        layout: WallpaperLayout,
        showTranslation: Bool,
        showExample: Bool,
        showExampleTranslation: Bool,
        showInflection: Bool,
        showHourStamp: Bool,
        emberIntensity: Double,
        grain: Double,
        vignette: Double,
        seed: UInt64,
        canvasID: String?,
        supersample: Bool
    ) {
        self.levels = levels
        self.categories = categories
        self.partsOfSpeech = partsOfSpeech
        self.theme = theme
        self.layout = layout
        self.showTranslation = showTranslation
        self.showExample = showExample
        self.showExampleTranslation = showExampleTranslation
        self.showInflection = showInflection
        self.showHourStamp = showHourStamp
        self.emberIntensity = emberIntensity
        self.grain = grain
        self.vignette = vignette
        self.seed = seed
        self.canvasID = canvasID
        self.supersample = supersample
    }

    // Decoding is lenient so that adding a field in a later build does not
    // wipe a user's existing configuration.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = WallpaperSettings.default
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container.decode(T.self, forKey: key)) ?? fallback
        }
        levels = value(.levels, fallback.levels)
        categories = value(.categories, fallback.categories)
        partsOfSpeech = value(.partsOfSpeech, fallback.partsOfSpeech)
        theme = value(.theme, fallback.theme)
        layout = value(.layout, fallback.layout)
        showTranslation = value(.showTranslation, fallback.showTranslation)
        showExample = value(.showExample, fallback.showExample)
        showExampleTranslation = value(.showExampleTranslation, fallback.showExampleTranslation)
        showInflection = value(.showInflection, fallback.showInflection)
        showHourStamp = value(.showHourStamp, fallback.showHourStamp)
        emberIntensity = value(.emberIntensity, fallback.emberIntensity)
        grain = value(.grain, fallback.grain)
        vignette = value(.vignette, fallback.vignette)
        seed = value(.seed, fallback.seed)
        canvasID = try? container.decodeIfPresent(String.self, forKey: .canvasID)
        supersample = value(.supersample, fallback.supersample)
        if levels.isEmpty { levels = fallback.levels }
    }
}

public enum WallpaperLayout: String, Codable, CaseIterable, Sendable {
    /// Keeps the top 42% clear for the clock and leaves room for the two
    /// bottom controls; the word sits in the readable middle band.
    case lockScreen
    /// Centred and dimmer, so app icons stay legible on top of it.
    case homeScreen
    /// No system furniture assumed — the design uses the whole frame.
    case poster

    public var title: String {
        switch self {
        case .lockScreen: "Lock Screen"
        case .homeScreen: "Home Screen"
        case .poster: "Poster"
        }
    }

    public var subtitle: String {
        switch self {
        case .lockScreen: "Clear space under the clock, word in the middle band"
        case .homeScreen: "Centred and dimmed so icons stay readable"
        case .poster: "Full frame, no system UI assumed"
        }
    }
}
