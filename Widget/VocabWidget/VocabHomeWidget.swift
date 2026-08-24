import SwiftUI
import VocabKit
import WidgetKit

struct VocabHomeWidget: Widget {
    let kind = "VocabHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VocabTimelineProvider()) { entry in
            VocabHomeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    EmberBackdrop(entry: entry.vocab, hourIndex: entry.hourIndex)
                }
        }
        .configurationDisplayName("Wort der Stunde")
        .description("A new German word every hour, in ember on black.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct VocabHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VocabTimelineEntry

    var body: some View {
        VocabHomeCard(
            entry: entry.vocab,
            hourIndex: entry.hourIndex,
            compact: family == .systemSmall,
            showExample: family != .systemSmall
        )
        .padding(family == .systemSmall ? 12 : 16)
    }
}
