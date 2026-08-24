import Foundation

/// One vocabulary item as stored in `vocabulary.json`.
public struct VocabEntry: Codable, Identifiable, Hashable, Sendable {

    public enum PartOfSpeech: String, Codable, CaseIterable, Sendable {
        case noun, verb, adjective, adverb, conjunction, preposition, phrase

        public var englishLabel: String {
            switch self {
            case .noun: "noun"
            case .verb: "verb"
            case .adjective: "adjective"
            case .adverb: "adverb"
            case .conjunction: "conjunction"
            case .preposition: "preposition"
            case .phrase: "phrase"
            }
        }

        public var germanLabel: String {
            switch self {
            case .noun: "Substantiv"
            case .verb: "Verb"
            case .adjective: "Adjektiv"
            case .adverb: "Adverb"
            case .conjunction: "Konjunktion"
            case .preposition: "Präposition"
            case .phrase: "Wendung"
            }
        }

        /// Label for the line above the headword on the wallpaper.
        public var inflectionCaption: String {
            switch self {
            case .noun: "Plural"
            case .verb: "Stammformen"
            case .adjective: "Steigerung"
            default: "Form"
            }
        }
    }

    public enum Level: String, Codable, CaseIterable, Comparable, Sendable {
        case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1"

        public static func < (lhs: Level, rhs: Level) -> Bool {
            guard let l = Self.allCases.firstIndex(of: lhs),
                  let r = Self.allCases.firstIndex(of: rhs) else { return false }
            return l < r
        }
    }

    /// Grammatical gender, derived from the definite article.
    public enum Gender: String, Sendable {
        case masculine = "der", feminine = "die", neuter = "das"
    }

    public let id: String
    public let word: String
    public let article: String?
    public let inflection: String?
    public let translation: String
    public let partOfSpeech: PartOfSpeech
    public let level: Level
    public let category: String
    public let example: String
    public let exampleTranslation: String

    private enum CodingKeys: String, CodingKey {
        case id, word, article, inflection, translation
        case partOfSpeech = "pos"
        case level, category, example, exampleTranslation
    }

    public init(
        id: String,
        word: String,
        article: String? = nil,
        inflection: String? = nil,
        translation: String,
        partOfSpeech: PartOfSpeech,
        level: Level,
        category: String,
        example: String,
        exampleTranslation: String
    ) {
        self.id = id
        self.word = word
        self.article = article
        self.inflection = inflection
        self.translation = translation
        self.partOfSpeech = partOfSpeech
        self.level = level
        self.category = category
        self.example = example
        self.exampleTranslation = exampleTranslation
    }

    public var gender: Gender? {
        guard let article else { return nil }
        return Gender(rawValue: article)
    }

    /// `die Freiheit` for nouns, the bare word otherwise.
    public var headword: String {
        guard let article else { return word }
        return "\(article) \(word)"
    }

    /// The span of `example` that holds this word, so the wallpaper can
    /// highlight it inside its own sentence. Matching is done on a crude stem
    /// and then widened back out to the whole token, so `laufen` lights up
    /// `läuft` and `Haus` lights up `Hauses`.
    public var exampleHighlight: Range<String.Index>? {
        let stem = Self.stem(of: word)
        guard stem.count >= 3,
              let hit = example.range(of: stem, options: [.caseInsensitive, .diacriticInsensitive])
        else { return nil }

        var lower = hit.lowerBound
        while lower > example.startIndex {
            let previous = example.index(before: lower)
            guard example[previous].isLetter else { break }
            lower = previous
        }
        var upper = hit.upperBound
        while upper < example.endIndex, example[upper].isLetter {
            upper = example.index(after: upper)
        }
        return lower..<upper
    }

    /// Crude stem so that `laufen` still matches `läuft` and `Häuser` matches `Haus`.
    static func stem(of word: String) -> String {
        let base = word.split(separator: " ").last.map(String.init) ?? word
        for suffix in ["en", "ern", "eln", "e"] where base.count > suffix.count + 3 {
            if base.hasSuffix(suffix) { return String(base.dropLast(suffix.count)) }
        }
        return base
    }
}
