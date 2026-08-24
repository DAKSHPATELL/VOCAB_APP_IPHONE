import XCTest
@testable import VocabKit

final class LibraryTests: XCTestCase {

    private let library = VocabularyLibrary.shared

    func testCorpusLoads() throws {
        XCTAssertGreaterThan(library.entries.count, 200,
                             "the bundled vocabulary.json failed to load")
    }

    func testIdentifiersAreUnique() {
        let ids = library.entries.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryNounHasAnArticle() {
        for entry in library.entries where entry.partOfSpeech == .noun {
            XCTAssertNotNil(entry.gender, "\(entry.word) has no usable article")
        }
    }

    func testNothingButNounsCarriesAnArticle() {
        for entry in library.entries where entry.partOfSpeech != .noun {
            XCTAssertNil(entry.article, "\(entry.word) should not have an article")
        }
    }

    func testEveryEntryHasBothSidesOfTheExample() {
        for entry in library.entries {
            XCTAssertFalse(entry.example.isEmpty, "\(entry.word) has no example")
            XCTAssertFalse(entry.exampleTranslation.isEmpty,
                           "\(entry.word) has no example translation")
            XCTAssertFalse(entry.translation.isEmpty, "\(entry.word) has no translation")
        }
    }

    func testMostExamplesContainTheirOwnWord() {
        let matched = library.entries.filter { $0.exampleHighlight != nil }
        let ratio = Double(matched.count) / Double(library.entries.count)
        XCTAssertGreaterThan(ratio, 0.75,
                             "only \(Int(ratio * 100))% of examples highlight their headword")
    }

    func testDeckHonoursLevelFilter() {
        var settings = WallpaperSettings.default
        settings.levels = [.a1]
        let deck = library.deck(matching: settings)
        XCTAssertFalse(deck.isEmpty)
        XCTAssertTrue(deck.entries.allSatisfy { $0.level == .a1 })
    }

    func testDeckHonoursPartOfSpeechFilter() {
        var settings = WallpaperSettings.default
        settings.partsOfSpeech = [.verb]
        let deck = library.deck(matching: settings)
        XCTAssertTrue(deck.entries.allSatisfy { $0.partOfSpeech == .verb })
    }

    func testImpossibleFilterFallsBackToTheWholeCorpus() {
        var settings = WallpaperSettings.default
        settings.categories = ["there-is-no-such-category"]
        let deck = library.deck(matching: settings)
        XCTAssertEqual(deck.count, library.entries.count,
                       "an empty filter result must not produce an empty wallpaper")
    }

    func testCycleLengthIsAtLeastAWeek() {
        let deck = library.deck(matching: .default)
        XCTAssertGreaterThan(deck.cycleDuration, 7 * 24 * 3_600)
    }
}

final class SettingsTests: XCTestCase {

    func testRoundTrip() throws {
        var settings = WallpaperSettings.default
        settings.seed = 0xDEAD_BEEF
        settings.levels = [.b1, .b2]
        settings.canvasID = "iphone-6.9"

        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(WallpaperSettings.self, from: data)
        XCTAssertEqual(settings, restored)
    }

    func testPartialJSONFallsBackToDefaults() throws {
        let json = Data(#"{"seed":7,"grain":0.9}"#.utf8)
        let settings = try JSONDecoder().decode(WallpaperSettings.self, from: json)
        XCTAssertEqual(settings.seed, 7)
        XCTAssertEqual(settings.grain, 0.9, accuracy: 0.0001)
        XCTAssertEqual(settings.levels, WallpaperSettings.default.levels)
        XCTAssertEqual(settings.layout, WallpaperSettings.default.layout)
    }

    func testEmptyLevelSetIsRepaired() throws {
        let json = Data(#"{"levels":[]}"#.utf8)
        let settings = try JSONDecoder().decode(WallpaperSettings.self, from: json)
        XCTAssertFalse(settings.levels.isEmpty)
    }
}

final class DeviceCanvasTests: XCTestCase {

    func testPointSizeMultipliesBackToPixels() {
        for canvas in DeviceCanvas.presets {
            XCTAssertEqual(canvas.pointSize.width * canvas.scale,
                           CGFloat(canvas.pixelWidth), accuracy: 0.001)
            XCTAssertEqual(canvas.pointSize.height * canvas.scale,
                           CGFloat(canvas.pixelHeight), accuracy: 0.001)
        }
    }

    func testPresetIdentifiersAreUnique() {
        let ids = DeviceCanvas.presets.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryPresetIsPortrait() {
        for canvas in DeviceCanvas.presets {
            XCTAssertLessThan(canvas.pixelWidth, canvas.pixelHeight, "\(canvas.name)")
        }
    }
}
