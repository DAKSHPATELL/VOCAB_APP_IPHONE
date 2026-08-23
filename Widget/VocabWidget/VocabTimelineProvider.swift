import Foundation
import VocabKit
import WidgetKit

struct VocabTimelineEntry: TimelineEntry {
    let date: Date
    let hourIndex: Int
    let vocab: VocabEntry

    var hourStart: Date { date }
    var hourEnd: Date { date.addingTimeInterval(TimeInterval(HourlyRotation.secondsPerHour)) }
}

/// The widget never fetches anything. It reads the user's settings from the
/// App Group, rebuilds the same deterministic deck the app uses, and writes out
/// a day of hourly entries in one go — so it keeps ticking correctly even if
/// the extension is never woken again.
struct VocabTimelineProvider: TimelineProvider {

    private static let hoursPerTimeline = 24

    func placeholder(in context: Context) -> VocabTimelineEntry {
        entry(at: .now) ?? .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (VocabTimelineEntry) -> Void) {
        completion(entry(at: .now) ?? .preview)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VocabTimelineEntry>) -> Void) {
        let settings = SharedStore.loadSettings()
        let deck = VocabularyLibrary.shared.deck(matching: settings)

        let scheduled = deck.schedule(from: .now, count: Self.hoursPerTimeline)
        guard !scheduled.isEmpty else {
            let fallback = VocabTimelineEntry.preview
            completion(Timeline(entries: [fallback], policy: .after(
                HourlyRotation.nextChange(after: .now)
            )))
            return
        }

        let entries = scheduled.map {
            VocabTimelineEntry(date: $0.date, hourIndex: $0.hourIndex, vocab: $0.entry)
        }
        // `.atEnd` asks WidgetKit for a refresh once the last entry is shown;
        // if the system is stingy the timeline still covers a full day.
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> VocabTimelineEntry? {
        let settings = SharedStore.loadSettings()
        let deck = VocabularyLibrary.shared.deck(matching: settings)
        guard let vocab = deck.entry(at: date) else { return nil }
        return VocabTimelineEntry(
            date: HourlyRotation.startOfHour(containing: date),
            hourIndex: HourlyRotation.hourIndex(for: date),
            vocab: vocab
        )
    }
}

extension VocabTimelineEntry {
    /// Used for the widget gallery and as a last-resort fallback.
    static let preview = VocabTimelineEntry(
        date: .now,
        hourIndex: HourlyRotation.hourIndex(for: .now),
        vocab: VocabEntry(
            id: "die-freiheit",
            word: "Freiheit",
            article: "die",
            inflection: "die Freiheiten",
            translation: "freedom, liberty",
            partOfSpeech: .noun,
            level: .a2,
            category: "abstract",
            example: "Freiheit bedeutet auch Verantwortung.",
            exampleTranslation: "Freedom also means responsibility."
        )
    )
}
