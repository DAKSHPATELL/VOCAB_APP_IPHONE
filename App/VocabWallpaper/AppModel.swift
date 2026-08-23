import Foundation
import Observation
import SwiftUI
import VocabKit

/// Single source of truth for the app process. The widget process reads the
/// same settings straight out of the App Group, so the two never drift.
@Observable
final class AppModel {

    /// Bound directly by the settings screen. Persistence is driven from
    /// `RootView` via `onChange` rather than a `didSet`: the `@Observable`
    /// macro rewrites stored properties into computed ones, and property
    /// observers on them are a trap.
    var settings: WallpaperSettings
    var favourites: Set<String>

    let library = VocabularyLibrary.shared

    init() {
        settings = SharedStore.loadSettings()
        favourites = SharedStore.loadFavourites()
    }

    @ObservationIgnored
    private var cachedDeck: (settings: WallpaperSettings, deck: VocabularyDeck)?

    /// Rebuilt only when the filters actually change — `deck` is read several
    /// times per body evaluation and filtering sorts the whole corpus.
    var deck: VocabularyDeck {
        if let cached = cachedDeck, cached.settings == settings { return cached.deck }
        let built = library.deck(matching: settings)
        cachedDeck = (settings, built)
        return built
    }

    var canvas: DeviceCanvas { DeviceCanvas.resolved(from: settings) }

    func entry(at date: Date = .now) -> VocabEntry? {
        deck.entry(at: date)
    }

    func hourIndex(at date: Date = .now) -> Int {
        HourlyRotation.hourIndex(for: date)
    }

    func upcoming(from date: Date = .now, count: Int = 8) -> [ScheduledEntry] {
        deck.schedule(from: date, count: count)
    }

    /// Fraction of the current hour already elapsed — drives the countdown ring.
    func hourProgress(at date: Date = .now) -> Double {
        let start = HourlyRotation.startOfHour(containing: date)
        return min(max(date.timeIntervalSince(start) / 3_600, 0), 1)
    }

    func secondsUntilNextWord(at date: Date = .now) -> Int {
        Int(HourlyRotation.nextChange(after: date).timeIntervalSince(date).rounded(.up))
    }

    // MARK: - Mutations

    func reshuffleDeck() {
        settings.seed = UInt64.random(in: UInt64.min...UInt64.max)
    }

    func resetToDefaults() {
        settings = .default
    }

    /// Called from `RootView.onChange`, so every mutation route persists.
    func persistSettings() { SharedStore.save(settings) }

    func persistFavourites() { SharedStore.save(favourites: favourites) }

    func toggleFavourite(_ entry: VocabEntry) {
        if favourites.contains(entry.id) {
            favourites.remove(entry.id)
        } else {
            favourites.insert(entry.id)
        }
    }

    func isFavourite(_ entry: VocabEntry) -> Bool {
        favourites.contains(entry.id)
    }

    /// A stand-in used only when the corpus somehow fails to load, so the UI
    /// degrades to a visible message instead of an empty screen.
    static let placeholder = VocabEntry(
        id: "placeholder",
        word: "Feuer",
        article: "das",
        inflection: "die Feuer",
        translation: "fire",
        partOfSpeech: .noun,
        level: .a1,
        category: "nature",
        example: "Das Feuer brennt die ganze Nacht.",
        exampleTranslation: "The fire burns all night long."
    )
}

extension Int {
    /// `01:07` style countdown.
    var countdownText: String {
        let minutes = self / 60
        let seconds = self % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
