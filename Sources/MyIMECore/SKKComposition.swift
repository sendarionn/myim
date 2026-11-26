import Foundation

/// A composition begun with a capital typed with Shift in SKK mode: the
/// first capital starts the conversion and the first capital after a
/// lowercase letter marks where the okurigana start, as `KaKu` does for
/// か + く, 書く, and `TORituKe` for とりつ + け. It keeps the keys as typed
/// and reads the stem and the okurigana from them, so they always agree
public struct SKKComposition: Equatable, Sendable {
    /// The keys as typed, capitals kept
    public private(set) var typed: String

    public init(firstLetter: Character) {
        typed = String(firstLetter)
    }

    /// The keys as romaji, which is what the composition holds
    public var romaji: String { typed.lowercased() }

    /// Where the okurigana start in `typed`: the first capital after a
    /// lowercase letter. Capitals typed together at the start, as the TOR of
    /// TORituKe, are the stem, and capitals alone, as SKK, mark nothing. It
    /// follows the keys, so it is found again after Delete
    public var okuriganaStart: Int? {
        var seenLowercase = false
        for (index, character) in typed.enumerated() {
            if character.isLowercase {
                seenLowercase = true
            } else if seenLowercase, character.isUppercase {
                return index
            }
        }
        return nil
    }

    /// A key typed at the end
    public mutating func type(_ character: Character) {
        typed.append(character)
    }

    /// The keys after Delete left `length` of them
    public mutating func shorten(to length: Int) {
        typed = String(typed.prefix(length))
    }

    /// The romaji before and after the okurigana mark
    public var parts: (stem: String, okurigana: String) {
        let romaji = Array(self.romaji)
        guard let start = okuriganaStart, start < romaji.count else {
            return (self.romaji, "")
        }
        return (String(romaji[..<start]), String(romaji[start...]))
    }

    public struct Reading: Equatable, Sendable {
        public let stem: String
        public let okurigana: String
        /// The SKK dictionary key of okuri-ari entries, as かk
        public let okuriAriKey: String
    }

    /// The kana of the stem and the okurigana, once both read as kana
    public func reading(converter: RomajiConverter = RomajiConverter()) -> Reading? {
        let parts = parts
        guard !parts.okurigana.isEmpty,
              let stem = converter.hiragana(from: parts.stem),
              let okurigana = converter.hiragana(from: parts.okurigana),
              let letter = parts.okurigana.first else { return nil }
        return Reading(stem: stem, okurigana: okurigana, okuriAriKey: stem + String(letter))
    }
}

/// Conversion candidates for an SKK composition. Without okurigana they are
/// the ordinary candidates of the reading, in their order. With okurigana,
/// as `KaKu`, the okurigana say what is meant, so the SKK dictionaries'
/// okuri-ari entries for かk come first in the dictionaries' order, with the
/// okurigana after them, whatever the ordinary ranking or learning; then
/// the ordinary candidates of the whole reading that end in the okurigana
/// and convert the stem, so 書く and 描く stay while 角 and かく go; then the
/// kana. The keys as typed close the list, so a capitalized English word
/// can still be entered
public enum SKKCandidateComposer {
    public static func candidates(
        input: String,
        composition: SKKComposition,
        standard: [Candidate],
        okuriAri: (String) -> [String],
        converter: RomajiConverter = RomajiConverter()
    ) -> [Candidate] {
        guard composition.okuriganaStart != nil else {
            return appendingTyped(composition.typed, to: standard, reading: input)
        }
        // The okurigana are still being typed
        guard let reading = composition.reading(converter: converter) else { return [] }
        let stemKatakana = converter.katakana(from: composition.parts.stem)
        var seen = Set<String>()
        var result: [Candidate] = []
        func append(_ candidate: Candidate) {
            if seen.insert(candidate.storageText).inserted {
                result.append(candidate)
            }
        }
        for word in okuriAri(reading.okuriAriKey) {
            append(Candidate(
                storageText: word + reading.okurigana,
                source: .importedDictionary,
                reading: input
            ))
        }
        for candidate in standard where candidate.storageText.hasSuffix(reading.okurigana) {
            let converted = String(candidate.storageText.dropLast(reading.okurigana.count))
            guard !converted.isEmpty, converted != reading.stem, converted != stemKatakana
            else { continue }
            append(candidate)
        }
        append(Candidate(
            storageText: reading.stem + reading.okurigana,
            source: .automaticKana,
            reading: input
        ))
        return appendingTyped(composition.typed, to: result, reading: input)
    }

    private static func appendingTyped(
        _ typed: String,
        to candidates: [Candidate],
        reading: String
    ) -> [Candidate] {
        guard !candidates.contains(where: { $0.storageText == typed }) else {
            return candidates
        }
        return candidates + [Candidate(storageText: typed, source: .uppercase, reading: reading)]
    }
}
