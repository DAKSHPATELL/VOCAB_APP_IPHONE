import SwiftUI

/// The wallpaper itself.
///
/// Every dimension is derived from `size.height`, so the identical view renders
/// correctly at 200 pt in a preview card and at 2868 px on a 6.9″ panel. Nothing
/// here is hard-coded in absolute points.
public struct WallpaperCanvas: View {

    public let entry: VocabEntry
    public let hourIndex: Int
    public let size: CGSize
    public let settings: WallpaperSettings

    public init(entry: VocabEntry, hourIndex: Int, size: CGSize, settings: WallpaperSettings) {
        self.entry = entry
        self.hourIndex = hourIndex
        self.size = size
        self.settings = settings
    }

    private var metrics: Metrics { Metrics(size: size, layout: settings.layout) }
    private var accent: Color { Ember.accent(for: entry) }

    public var body: some View {
        ZStack {
            ground
            emberField
            horizon
            if settings.grain > 0.01 { grainLayer }
            vignette
            content
        }
        .frame(width: size.width, height: size.height)
        .background(Ember.void)
        .clipped()
        .environment(\.colorScheme, .dark)
        // Deliberately no `.drawingGroup()` here: it is a Metal fast path that
        // `ImageRenderer` cannot rasterise, and offscreen export matters more
        // than a few frames of on-screen scrolling performance.
    }

    // MARK: - Background

    private var ground: some View {
        LinearGradient(
            stops: [
                .init(color: Ember.pitch, location: 0.0),
                .init(color: Ember.void, location: 0.34),
                .init(color: Ember.ash, location: 0.78),
                .init(color: Ember.soot, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Three or four soft radial blooms, placed by a generator seeded on the
    /// hour, so consecutive wallpapers are recognisably siblings but never
    /// pixel-identical.
    private var emberField: some View {
        let blooms = Bloom.field(hourIndex: hourIndex, seed: settings.seed, accent: accent)
        return ZStack {
            ForEach(Array(blooms.enumerated()), id: \.offset) { _, bloom in
                RadialGradient(
                    colors: [
                        bloom.color.opacity(0.85 * settings.emberIntensity),
                        bloom.color.opacity(0.22 * settings.emberIntensity),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: metrics.height * bloom.radius
                )
                .frame(
                    width: metrics.height * bloom.radius * 2,
                    height: metrics.height * bloom.radius * 2
                )
                .position(
                    x: metrics.width * bloom.x,
                    y: metrics.height * bloom.y
                )
                .blendMode(.screen)
            }
        }
        .blur(radius: metrics.height * 0.02)
        .opacity(settings.layout == .homeScreen ? 0.72 : 1)
    }

    /// A low band of heat along the bottom edge — the "coals" of the design.
    private var horizon: some View {
        LinearGradient(
            colors: [
                .clear,
                Ember.blood.opacity(0.18 * settings.emberIntensity),
                Ember.ember.opacity(0.30 * settings.emberIntensity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: metrics.height * 0.34)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .blendMode(.screen)
        .blur(radius: metrics.height * 0.03)
    }

    private var grainLayer: some View {
        Canvas(rendersAsynchronously: false) { context, canvasSize in
            var generator = SeededGenerator(seed: settings.seed &+ 0xA11CE)
            let unit = max(canvasSize.height / 1400, 0.7)
            let dustCount = Int(canvasSize.width * canvasSize.height / 900)

            for _ in 0..<dustCount {
                let x = generator.nextUnit() * canvasSize.width
                let y = generator.nextUnit() * canvasSize.height
                let alpha = generator.nextUnit() * 0.11 * settings.grain
                let rect = CGRect(x: x, y: y, width: unit, height: unit)
                context.fill(Path(rect), with: .color(Ember.bone.opacity(alpha)))
            }

            // A handful of brighter sparks, warmer and slightly larger.
            let sparkCount = Int(24 + 40 * settings.grain)
            for _ in 0..<sparkCount {
                let x = generator.nextUnit() * canvasSize.width
                let y = canvasSize.height * (0.35 + 0.65 * generator.nextUnit())
                let radius = unit * (0.8 + 1.9 * generator.nextUnit())
                let alpha = 0.10 + 0.40 * generator.nextUnit()
                let rect = CGRect(x: x, y: y, width: radius, height: radius)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Ember.amber.opacity(alpha * settings.grain))
                )
            }
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    private var vignette: some View {
        RadialGradient(
            colors: [
                .clear,
                Ember.void.opacity(0.35 * settings.vignette),
                Ember.void.opacity(0.92 * settings.vignette)
            ],
            center: .init(x: 0.5, y: 0.42),
            startRadius: metrics.height * 0.12,
            endRadius: metrics.height * 0.78
        )
        .allowsHitTesting(false)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if settings.showHourStamp {
                stampRow
                Spacer().frame(height: metrics.height * 0.022)
            }

            if let article = entry.article {
                Text(article)
                    .font(.system(size: metrics.articleSize, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(accent.opacity(0.92))
                    .shadow(color: accent.opacity(0.5), radius: metrics.height * 0.008)
                Spacer().frame(height: metrics.height * 0.004)
            }

            headword

            if settings.showTranslation {
                Spacer().frame(height: metrics.height * 0.014)
                Text(entry.translation)
                    .font(.system(size: metrics.translationSize, weight: .medium))
                    .foregroundStyle(Ember.bone.opacity(0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }

            if settings.showInflection, let inflection = entry.inflection {
                Spacer().frame(height: metrics.height * 0.012)
                HStack(spacing: metrics.height * 0.008) {
                    Text(entry.partOfSpeech.inflectionCaption.uppercased())
                        .font(.system(size: metrics.captionSize, weight: .semibold))
                        .tracking(metrics.captionSize * 0.16)
                        .foregroundStyle(accent.opacity(0.75))
                    Text(inflection)
                        .font(.system(size: metrics.metaSize, weight: .regular, design: .serif))
                        .foregroundStyle(Ember.smoke.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }

            if settings.showExample {
                Spacer().frame(height: metrics.height * 0.026)
                Rectangle()
                    .fill(Ember.hairline)
                    .frame(width: metrics.contentWidth * 0.62, height: max(metrics.height * 0.0013, 0.5))
                Spacer().frame(height: metrics.height * 0.022)

                Text(highlightedExample)
                    .font(.system(size: metrics.exampleSize, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Ember.bone.opacity(0.82))
                    .lineSpacing(metrics.exampleSize * 0.28)
                    .lineLimit(3)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.leading)

                if settings.showExampleTranslation {
                    Spacer().frame(height: metrics.height * 0.010)
                    Text(entry.exampleTranslation)
                        .font(.system(size: metrics.metaSize, weight: .regular))
                        .foregroundStyle(Ember.dust)
                        .lineSpacing(metrics.metaSize * 0.24)
                        .lineLimit(3)
                        .minimumScaleFactor(0.65)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        // Order matters: the insets have to be applied to the text block
        // *before* it is placed in the full-canvas frame. Padding a view that
        // already fills the canvas grows it past the edges instead of moving
        // it, which silently pushed the word off-frame.
        .frame(width: metrics.contentWidth, alignment: .leading)
        .padding(.leading, metrics.sideInset)
        .padding(.top, metrics.topInset)
        .padding(.bottom, metrics.bottomInset)
        .frame(
            width: metrics.width,
            height: metrics.height,
            alignment: metrics.contentAlignment
        )
        .opacity(settings.layout == .homeScreen ? 0.9 : 1)
    }

    private var stampRow: some View {
        HStack(spacing: metrics.height * 0.010) {
            Text(Self.hourStamp(for: hourIndex))
                .foregroundStyle(accent)
            dot
            Text(entry.level.rawValue)
                .foregroundStyle(Ember.smoke)
            dot
            Text(entry.partOfSpeech.germanLabel.uppercased())
                .foregroundStyle(Ember.smoke)
        }
        .font(.system(size: metrics.captionSize, weight: .semibold))
        .tracking(metrics.captionSize * 0.22)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private var dot: some View {
        Circle()
            .fill(Ember.dust.opacity(0.7))
            .frame(width: metrics.captionSize * 0.22, height: metrics.captionSize * 0.22)
    }

    private var headword: some View {
        Text(entry.word)
            .font(.system(size: metrics.wordSize(for: entry.word), weight: .bold, design: .serif))
            .tracking(-metrics.wordSize(for: entry.word) * 0.018)
            .foregroundStyle(Ember.accentGradient(for: entry))
            .lineLimit(2)
            .minimumScaleFactor(0.42)
            .multilineTextAlignment(.leading)
            .shadow(color: accent.opacity(0.55), radius: metrics.height * 0.020)
            .shadow(color: Ember.blood.opacity(0.35), radius: metrics.height * 0.045)
    }

    private var highlightedExample: AttributedString {
        var attributed = AttributedString(entry.example)
        guard let range = entry.exampleHighlight,
              let lower = AttributedString.Index(range.lowerBound, within: attributed),
              let upper = AttributedString.Index(range.upperBound, within: attributed)
        else { return attributed }
        attributed[lower..<upper].foregroundColor = accent
        attributed[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
        return attributed
    }

    static func hourStamp(for hourIndex: Int) -> String {
        let hour = ((hourIndex % 24) + 24) % 24
        return String(format: "%02d:00", hour)
    }
}

// MARK: - Layout maths

private struct Metrics {
    let size: CGSize
    let layout: WallpaperLayout

    var width: CGFloat { size.width }
    var height: CGFloat { size.height }

    var sideInset: CGFloat { width * 0.098 }
    var contentWidth: CGFloat { width - sideInset * 2 }

    /// Pairs with `topInset`/`bottomInset`: the padded block is anchored here
    /// inside the canvas, so `.topLeading` + a 30% top inset puts the word just
    /// below the clock, and `.leading` alone centres it vertically.
    var contentAlignment: Alignment {
        switch layout {
        case .lockScreen: .topLeading
        case .homeScreen: .leading
        case .poster: .bottomLeading
        }
    }

    /// Keeps the clock zone clear on the lock screen.
    var topInset: CGFloat {
        switch layout {
        case .lockScreen: height * 0.30
        case .homeScreen: 0
        case .poster: 0
        }
    }

    /// Clears the flashlight and camera buttons at the bottom of the lock screen.
    var bottomInset: CGFloat {
        switch layout {
        case .lockScreen: height * 0.16
        case .homeScreen: 0
        case .poster: height * 0.14
        }
    }

    var captionSize: CGFloat { height * 0.0125 }
    var metaSize: CGFloat { height * 0.0150 }
    var articleSize: CGFloat { height * 0.0270 }
    var translationSize: CGFloat { height * 0.0225 }
    var exampleSize: CGFloat { height * 0.0195 }

    /// Long compounds get a smaller starting point so `minimumScaleFactor`
    /// never has to squash them into illegibility.
    func wordSize(for word: String) -> CGFloat {
        let base = height * 0.076
        switch word.count {
        case 0...7: return base
        case 8...10: return base * 0.86
        case 11...13: return base * 0.72
        case 14...16: return base * 0.60
        default: return base * 0.50
        }
    }
}

// MARK: - Ember placement

private struct Bloom {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let color: Color

    /// Deterministic per hour: same hour, same picture.
    static func field(hourIndex: Int, seed: UInt64, accent: Color) -> [Bloom] {
        var generator = SeededGenerator(
            seed: seed &+ UInt64(bitPattern: Int64(hourIndex)) &* 0x2545_F491_4F6C_DD1D
        )
        let palette: [Color] = [Ember.ember, Ember.orange, Ember.blood, accent, Ember.crimson]

        return (0..<4).map { index in
            let color = palette[generator.next(upperBound: palette.count)]
            // One bloom is always pinned low so the "coals" read consistently.
            let y: CGFloat = index == 0
                ? 0.80 + 0.14 * generator.nextUnit()
                : 0.10 + 0.75 * generator.nextUnit()
            return Bloom(
                x: 0.05 + 0.90 * generator.nextUnit(),
                y: y,
                radius: 0.20 + 0.26 * generator.nextUnit(),
                color: color
            )
        }
    }
}
