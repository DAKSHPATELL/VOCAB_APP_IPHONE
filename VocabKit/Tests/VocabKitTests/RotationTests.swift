import XCTest
@testable import VocabKit

final class RotationTests: XCTestCase {

    private let deck = VocabularyDeck(
        entries: (0..<50).map { index in
            VocabEntry(
                id: "w\(index)", word: "Wort\(index)", translation: "word \(index)",
                partOfSpeech: .noun, level: .a1, category: "test",
                example: "Beispiel \(index).", exampleTranslation: "Example \(index)."
            )
        },
        seed: 42
    )

    func testEveryWordAppearsExactlyOncePerCycle() {
        let hits = (0..<deck.count).compactMap { deck.entry(atHour: $0)?.id }
        XCTAssertEqual(hits.count, deck.count)
        XCTAssertEqual(Set(hits).count, deck.count, "a word repeated inside one cycle")
    }

    func testConsecutiveCyclesUseDifferentOrders() {
        let first = (0..<deck.count).compactMap { deck.entry(atHour: $0)?.id }
        let second = (deck.count..<(deck.count * 2)).compactMap { deck.entry(atHour: $0)?.id }
        XCTAssertEqual(Set(first), Set(second))
        XCTAssertNotEqual(first, second, "the deck was not reshuffled between cycles")
    }

    func testSelectionIsDeterministic() {
        for hour in stride(from: -5_000, through: 5_000, by: 137) {
            XCTAssertEqual(deck.entry(atHour: hour)?.id, deck.entry(atHour: hour)?.id)
        }
    }

    func testDifferentSeedsDiverge() {
        let other = VocabularyDeck(entries: deck.entries, seed: 43)
        let mine = (0..<deck.count).compactMap { deck.entry(atHour: $0)?.id }
        let theirs = (0..<deck.count).compactMap { other.entry(atHour: $0)?.id }
        XCTAssertNotEqual(mine, theirs)
    }

    func testNegativeHoursStayInRange() {
        for hour in -10_000...(-9_900) {
            let position = HourlyRotation.deckPosition(hourIndex: hour, count: 50, seed: 7)
            XCTAssertTrue((0..<50).contains(position), "position \(position) out of range")
        }
    }

    func testSingleEntryDeckAlwaysResolves() {
        let single = VocabularyDeck(entries: [deck.entries[0]], seed: 1)
        XCTAssertEqual(single.entry(atHour: 12_345)?.id, "w0")
    }

    func testEmptyDeckReturnsNil() {
        let empty = VocabularyDeck(entries: [], seed: 1)
        XCTAssertNil(empty.entry(atHour: 0))
        XCTAssertTrue(empty.schedule(from: Date(), count: 24).isEmpty)
    }
}

final class HourlyRotationTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!

    func testHourIndexAdvancesOncePerHour() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let first = HourlyRotation.hourIndex(for: start, timeZone: utc)
        let later = HourlyRotation.hourIndex(for: start.addingTimeInterval(3_600), timeZone: utc)
        XCTAssertEqual(later, first + 1)
    }

    func testHourIndexIsStableInsideAnHour() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let expected = HourlyRotation.hourIndex(for: base, timeZone: utc)
        for offset in stride(from: 0.0, to: 3_599.0, by: 421) {
            XCTAssertEqual(
                HourlyRotation.hourIndex(for: base.addingTimeInterval(offset), timeZone: utc),
                expected
            )
        }
    }

    func testNextChangeIsAlwaysWithinTheHour() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for offset in stride(from: 0.0, to: 86_400.0, by: 617) {
            let now = base.addingTimeInterval(offset)
            let next = HourlyRotation.nextChange(after: now, timeZone: utc)
            let delta = next.timeIntervalSince(now)
            XCTAssertGreaterThan(delta, 0)
            XCTAssertLessThanOrEqual(delta, 3_600)
        }
    }

    func testNextChangeLandsOnAWholeHour() {
        let now = Date(timeIntervalSince1970: 1_700_001_234)
        let next = HourlyRotation.nextChange(after: now, timeZone: utc)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let parts = calendar.dateComponents([.minute, .second, .nanosecond], from: next)
        XCTAssertEqual(parts.minute, 0)
        XCTAssertEqual(parts.second, 0)
    }

    func testStartOfHourPrecedesNow() {
        let now = Date(timeIntervalSince1970: 1_700_001_234)
        let start = HourlyRotation.startOfHour(containing: now, timeZone: utc)
        XCTAssertLessThanOrEqual(start, now)
        XCTAssertEqual(
            HourlyRotation.hourIndex(for: start, timeZone: utc),
            HourlyRotation.hourIndex(for: now, timeZone: utc)
        )
    }

    func testScheduleIsContiguousAndHourly() {
        let deck = VocabularyDeck(entries: VocabularyLibrary.shared.entries, seed: 9)
        let schedule = deck.schedule(from: Date(), count: 24, timeZone: utc)
        XCTAssertEqual(schedule.count, 24)
        for (previous, next) in zip(schedule, schedule.dropFirst()) {
            XCTAssertEqual(next.hourIndex, previous.hourIndex + 1)
            XCTAssertEqual(next.date.timeIntervalSince(previous.date), 3_600, accuracy: 0.001)
        }
    }
}

final class SeededGeneratorTests: XCTestCase {

    func testSameSeedProducesSameStream() {
        var a = SeededGenerator(seed: 1234)
        var b = SeededGenerator(seed: 1234)
        for _ in 0..<128 { XCTAssertEqual(a.next(), b.next()) }
    }

    func testBoundedValuesStayInRange() {
        var generator = SeededGenerator(seed: 99)
        for _ in 0..<10_000 {
            let value = generator.next(upperBound: 7)
            XCTAssertTrue((0..<7).contains(value))
        }
    }

    func testUnitValuesStayInRange() {
        var generator = SeededGenerator(seed: 5)
        for _ in 0..<10_000 {
            let value = generator.nextUnit()
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThan(value, 1)
        }
    }

    func testShuffleIsAPermutation() {
        var generator = SeededGenerator(seed: 77)
        let shuffled = Array(0..<200).deterministicallyShuffled(using: &generator)
        XCTAssertEqual(Set(shuffled), Set(0..<200))
        XCTAssertNotEqual(shuffled, Array(0..<200))
    }
}
