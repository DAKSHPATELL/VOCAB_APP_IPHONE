import SwiftUI
import VocabKit
import WidgetKit

/// Lock Screen accessories. iOS renders these in a desaturated vibrant style,
/// so the ember palette deliberately does not appear here — legibility on the
/// user's own wallpaper wins.
struct VocabLockWidget: Widget {
    let kind = "VocabLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VocabTimelineProvider()) { entry in
            VocabLockWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Wort der Stunde")
        .description("The current word on your Lock Screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct VocabLockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VocabTimelineEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            VocabAccessoryInline(entry: entry.vocab)

        case .accessoryCircular:
            // A live ring rather than a static value: WidgetKit animates
            // `timerInterval` progress without extra timeline entries.
            ProgressView(timerInterval: entry.hourStart...entry.hourEnd, countsDown: false) {
                Text(entry.vocab.level.rawValue)
            } currentValueLabel: {
                Text(entry.vocab.article ?? String(entry.vocab.word.prefix(2)))
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .minimumScaleFactor(0.5)
            }
            .progressViewStyle(.circular)

        default:
            VocabAccessoryRectangular(entry: entry.vocab)
        }
    }
}
