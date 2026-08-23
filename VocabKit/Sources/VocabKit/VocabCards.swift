import SwiftUI

/// A compact ember-styled background used by home-screen widgets and preview
/// chrome inside the app. It is the wallpaper's palette without the wallpaper's
/// layout maths.
public struct EmberBackdrop: View {
    public let entry: VocabEntry
    public let hourIndex: Int

    public init(entry: VocabEntry, hourIndex: Int) {
        self.entry = entry
        self.hourIndex = hourIndex
    }

    public var body: some View {
        let accent = Ember.accent(for: entry)
        ZStack {
            LinearGradient(
                colors: [Ember.pitch, Ember.void, Ember.ash],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [accent.opacity(0.45), .clear],
                center: .init(x: 0.82, y: 0.88),
                startRadius: 0,
                endRadius: 220
            )
            .blendMode(.screen)
            RadialGradient(
                colors: [Ember.blood.opacity(0.35), .clear],
                center: .init(x: 0.10, y: 0.12),
                startRadius: 0,
                endRadius: 180
            )
            .blendMode(.screen)
        }
    }
}

/// Home-screen widget content. `compact` drops the example sentence for the
/// small family, where there is simply no room for it.
public struct VocabHomeCard: View {
    public let entry: VocabEntry
    public let hourIndex: Int
    public let compact: Bool
    public let showExample: Bool

    public init(entry: VocabEntry, hourIndex: Int, compact: Bool, showExample: Bool) {
        self.entry = entry
        self.hourIndex = hourIndex
        self.compact = compact
        self.showExample = showExample
    }

    public var body: some View {
        let accent = Ember.accent(for: entry)
        VStack(alignment: .leading, spacing: compact ? 2 : 5) {
            HStack(spacing: 5) {
                Text(WallpaperCanvas.hourStamp(for: hourIndex))
                    .foregroundStyle(accent)
                Text(entry.level.rawValue)
                    .foregroundStyle(Ember.dust)
                if !compact {
                    Text(entry.partOfSpeech.germanLabel.uppercased())
                        .foregroundStyle(Ember.dust)
                }
            }
            .font(.system(size: compact ? 9 : 10, weight: .semibold))
            .tracking(1.1)
            .lineLimit(1)

            Spacer(minLength: 0)

            if let article = entry.article {
                Text(article)
                    .font(.system(size: compact ? 12 : 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(accent.opacity(0.9))
            }

            Text(entry.word)
                .font(.system(size: compact ? 24 : 34, weight: .bold, design: .serif))
                .foregroundStyle(Ember.accentGradient(for: entry))
                .lineLimit(2)
                .minimumScaleFactor(0.45)

            Text(entry.translation)
                .font(.system(size: compact ? 11 : 13, weight: .medium))
                .foregroundStyle(Ember.bone.opacity(0.85))
                .lineLimit(compact ? 2 : 1)
                .minimumScaleFactor(0.7)

            if showExample && !compact {
                Rectangle()
                    .fill(Ember.hairline)
                    .frame(height: 0.7)
                    .padding(.vertical, 3)
                Text(entry.example)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Ember.smoke)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Lock-screen accessory widget.
///
/// iOS renders accessory widgets in a desaturated vibrant mode, so the ember
/// palette cannot survive here — this view is built for tone and weight instead
/// of colour, which is why it looks deliberately different from the wallpaper.
public struct VocabAccessoryRectangular: View {
    public let entry: VocabEntry

    public init(entry: VocabEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.headword)
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(entry.translation)
                .font(.system(size: 12, weight: .regular))
                .opacity(0.85)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(entry.example)
                .font(.system(size: 11, weight: .regular, design: .serif))
                .opacity(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct VocabAccessoryInline: View {
    public let entry: VocabEntry

    public init(entry: VocabEntry) {
        self.entry = entry
    }

    public var body: some View {
        Text("\(entry.headword) · \(entry.translation)")
    }
}
