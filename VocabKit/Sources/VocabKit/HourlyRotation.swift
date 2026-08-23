import Foundation

/// Maps wall-clock time onto a word, deterministically.
///
/// The rotation walks a shuffled deck of every entry in the filtered deck.
/// Within one cycle (deck size × 1 hour) no word repeats; each new cycle is
/// reshuffled with a different seed. Because the shuffle depends only on the
/// cycle number and the user's seed, every process computes the same answer
/// offline — no network, no background refresh, no shared write.
public enum HourlyRotation {

    public static let secondsPerHour = 3_600

    /// Number of whole hours between the Unix epoch and `date`, in the user's
    /// local time zone, so the word flips exactly on the local hour mark.
    public static func hourIndex(for date: Date, timeZone: TimeZone = .current) -> Int {
        let shifted = date.timeIntervalSince1970 + Double(timeZone.secondsFromGMT(for: date))
        return Int((shifted / Double(secondsPerHour)).rounded(.down))
    }

    /// The instant the word changes next: the top of the following local hour.
    public static func nextChange(after date: Date, timeZone: TimeZone = .current) -> Date {
        let offset = Double(timeZone.secondsFromGMT(for: date))
        let shifted = date.timeIntervalSince1970 + offset
        let nextBoundary = (shifted / Double(secondsPerHour)).rounded(.down) + 1
        return Date(timeIntervalSince1970: nextBoundary * Double(secondsPerHour) - offset)
    }

    /// The start of the hour containing `date`.
    public static func startOfHour(containing date: Date, timeZone: TimeZone = .current) -> Date {
        nextChange(after: date, timeZone: timeZone)
            .addingTimeInterval(-Double(secondsPerHour))
    }

    /// Position in the deck for a given hour. `count` must be positive.
    public static func deckPosition(hourIndex: Int, count: Int, seed: UInt64) -> Int {
        precondition(count > 0, "the deck must not be empty")
        guard count > 1 else { return 0 }

        // Floor division so negative hour indices (dates before 1970) behave.
        let cycle = Int((Double(hourIndex) / Double(count)).rounded(.down))
        let offset = hourIndex - cycle * count

        var generator = SeededGenerator(
            seed: seed ^ (UInt64(bitPattern: Int64(cycle)) &* 0xD1B5_4A32_D192_ED03)
        )
        let deck = Array(0..<count).deterministicallyShuffled(using: &generator)
        return deck[offset]
    }
}
