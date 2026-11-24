import Foundation

/// A composition begun with a capital typed with Shift in SKK mode: the
/// first capital starts the conversion and the next marks where the
/// okurigana start, as `KaKu` does for か + く, 書く. It keeps the keys as
/// typed and where the okurigana start, and reads the stem and the
/// okurigana from them, so they always agree
public struct SKKComposition: Equatable, Sendable {
    /// The keys as typed, capitals kept
    public private(set) var typed: String
    /// Where the okurigana start in `typed`, once marked
    public private(set) var okuriganaStart: Int?

    public init(firstLetter: Character) {
        typed = String(firstLetter)
    }

    /// The keys as romaji, which is what the composition holds
    public var romaji: String { typed.lowercased() }

    /// A key typed at the end; a capital typed with Shift after the first
    /// marks the okurigana there, once
    public mutating func type(_ character: Character, marksOkurigana: Bool) {
        if marksOkurigana, okuriganaStart == nil, !typed.isEmpty {
            okuriganaStart = typed.count
        }
        typed.append(character)
    }

    /// The keys after Delete left `length` of them; okurigana deleted
    /// entirely are no longer marked
    public mutating func shorten(to length: Int) {
        typed = String(typed.prefix(length))
        if let start = okuriganaStart, typed.count <= start {
            okuriganaStart = nil
        }
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
/// the ordinary candidates of the reading. With okurigana, as `KaKu`, the
/// ordinary candidates of the whole reading are kept where they end in the
/// okurigana and convert the stem, so 書く and 描く stay while 角 and かく
/// go; then the SKK dictionaries' okuri-ari entries for かk with the
/// okurigana after them, and the kana. The keys as typed close the list,
/// so a capitalized English word can still be entered
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
        for candidate in standard where candidate.storageText.hasSuffix(reading.okurigana) {
            let converted = String(candidate.storageText.dropLast(reading.okurigana.count))
            guard !converted.isEmpty, converted != reading.stem, converted != stemKatakana
            else { continue }
            append(candidate)
        }
        for word in okuriAri(reading.okuriAriKey) {
            append(Candidate(
                storageText: word + reading.okurigana,
                source: .importedDictionary,
                reading: input
            ))
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
