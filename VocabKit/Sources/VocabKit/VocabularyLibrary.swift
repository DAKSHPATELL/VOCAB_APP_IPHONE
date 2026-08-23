import Foundation

/// The full bundled corpus, loaded once.
public struct VocabularyLibrary: Sendable {

    public let entries: [VocabEntry]

    public static let shared: VocabularyLibrary = {
        do {
            return try VocabularyLibrary(bundle: .module)
        } catch {
            assertionFailure("vocabulary.json could not be loaded: \(error)")
            return VocabularyLibrary(entries: [])
        }
    }()

    public init(entries: [VocabEntry]) {
        self.entries = entries
    }

    public init(bundle: Bundle) throws {
        guard let url = bundle.url(forResource: "vocabulary", withExtension: "json") else {
            throw LoadError.resourceMissing
        }
        self = try VocabularyLibrary(data: Data(contentsOf: url))
    }

    public init(data: Data) throws {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        entries = payload.words
    }

    public enum LoadError: Error { case resourceMissing }

    private struct Payload: Decodable {
        let words: [VocabEntry]
    }

    public var levels: [VocabEntry.Level] {
        Array(Set(entries.map(\.level))).sorted()
    }

    public var categories: [String] {
        Array(Set(entries.map(\.category))).sorted()
    }

    public func entry(id: String) -> VocabEntry? {
        entries.first { $0.id == id }
    }

    /// Builds the rotating deck for the given filters. Falls back to the full
    /// corpus rather than showing nothing when the filters exclude everything.
    public func deck(matching settings: WallpaperSettings) -> VocabularyDeck {
        var filtered = entries.filter { settings.levels.contains($0.level) }
        if !settings.categories.isEmpty {
            filtered = filtered.filter { settings.categories.contains($0.category) }
        }
        if !settings.partsOfSpeech.isEmpty {
            filtered = filtered.filter { settings.partsOfSpeech.contains($0.partOfSpeech) }
        }
        if filtered.isEmpty { filtered = entries }
        return VocabularyDeck(entries: filtered.sorted { $0.id < $1.id }, seed: settings.seed)
    }
}

/// A filtered, seeded slice of the library that can answer "which word is it
/// right now?" without any stored state.
public struct VocabularyDeck: Sendable {

    public let entries: [VocabEntry]
    public let seed: UInt64

    public init(entries: [VocabEntry], seed: UInt64) {
        self.entries = entries
        self.seed = seed
    }

    public var isEmpty: Bool { entries.isEmpty }
    public var count: Int { entries.count }

    /// How long the deck lasts before a word can repeat.
    public var cycleDuration: TimeInterval {
        TimeInterval(entries.count * HourlyRotation.secondsPerHour)
    }

    public func entry(atHour hourIndex: Int) -> VocabEntry? {
        guard !entries.isEmpty else { return nil }
        let position = HourlyRotation.deckPosition(
            hourIndex: hourIndex, count: entries.count, seed: seed
        )
        return entries[position]
    }

    public func entry(at date: Date, timeZone: TimeZone = .current) -> VocabEntry? {
        entry(atHour: HourlyRotation.hourIndex(for: date, timeZone: timeZone))
    }

    /// `count` consecutive hours starting at the hour containing `date`.
    public func schedule(
        from date: Date,
        count: Int,
        timeZone: TimeZone = .current
    ) -> [ScheduledEntry] {
        guard !entries.isEmpty, count > 0 else { return [] }
        let firstHour = HourlyRotation.hourIndex(for: date, timeZone: timeZone)
        let start = HourlyRotation.startOfHour(containing: date, timeZone: timeZone)
        return (0..<count).compactMap { step in
            guard let entry = entry(atHour: firstHour + step) else { return nil }
            return ScheduledEntry(
                hourIndex: firstHour + step,
                date: start.addingTimeInterval(Double(step * HourlyRotation.secondsPerHour)),
                entry: entry
            )
        }
    }
}

public struct ScheduledEntry: Identifiable, Sendable {
    public let hourIndex: Int
    public let date: Date
    public let entry: VocabEntry

    public var id: Int { hourIndex }

    public init(hourIndex: Int, date: Date, entry: VocabEntry) {
        self.hourIndex = hourIndex
        self.date = date
        self.entry = entry
    }
}
