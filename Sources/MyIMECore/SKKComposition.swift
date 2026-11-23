import Foundation

/// A composition begun with a capital in SKK mode: the first capital starts
/// the conversion and the next marks where the okurigana start, as `KaKu`
/// does for 書く. The composition itself stays the ordinary lowercase input,
/// so editing, conversion and commit work as they do otherwise; this keeps
/// only what the capitals said
public struct SKKComposition: Equatable, Sendable {
    /// The input position where the okurigana start
    public private(set) var okuriganaStart: Int?
    /// The keys as typed, capitals kept, for an English word such as Swift
    public private(set) var typed: String

    public init(firstLetter: Character) {
        typed = String(firstLetter)
    }

    /// A letter typed at the end of the composition, which is `position`
    /// letters long before it; a capital after the first starts the
    /// okurigana there, once
    public mutating func type(_ letter: Character, at position: Int) {
        if letter.isUppercase, okuriganaStart == nil, position > 0 {
            okuriganaStart = position
        }
        typed.append(letter)
    }

    /// The composition became `length` letters long, as by Delete
    public mutating func shortened(to length: Int) {
        if let start = okuriganaStart, length <= start {
            okuriganaStart = nil
        }
        typed = String(typed.prefix(length))
    }

    /// The composition split at the okurigana
    public func parts(of input: String) -> (stem: String, okurigana: String) {
        guard let start = okuriganaStart, start < input.count else {
            return (input, "")
        }
        let index = input.index(input.startIndex, offsetBy: start)
        return (String(input[..<index]), String(input[index...]))
    }
}

/// Conversion candidates for an SKK composition. Without okurigana they are
/// the ordinary candidates. With okurigana, as `KaKu`, the stem is looked up
/// with the okurigana's first letter as an SKK okuri-ari entry (かk) and the
/// typed okurigana follow it; the ordinary candidates of the whole reading
/// are kept only where they end in that okurigana and convert the stem, so
/// 書く and 描く stay while 角 and かく go
public enum SKKCandidateComposer {
    public static func candidates(
        input: String,
        composition: SKKComposition,
        standard: [Candidate],
        okuriAri: (String) -> [String],
        converter: RomajiConverter = RomajiConverter()
    ) -> [Candidate] {
        let parts = composition.parts(of: input)
        guard !parts.okurigana.isEmpty else {
            return appendingTyped(composition.typed, to: standard, reading: input)
        }
        guard let stem = converter.hiragana(from: parts.stem),
              let okurigana = converter.hiragana(from: parts.okurigana),
              let okuriLetter = parts.okurigana.first?.lowercased()
        else {
            // The okurigana are still being typed
            return []
        }
        let stemKatakana = converter.katakana(from: parts.stem)
        var seen = Set<String>()
        var result: [Candidate] = []
        func append(_ candidate: Candidate) {
            if seen.insert(candidate.storageText).inserted {
                result.append(candidate)
            }
        }
        for word in okuriAri(stem + okuriLetter) {
            append(Candidate(
                storageText: word + okurigana,
                source: .importedDictionary,
                reading: input
            ))
        }
        for candidate in standard where candidate.storageText.hasSuffix(okurigana) {
            let converted = String(candidate.storageText.dropLast(okurigana.count))
            guard !converted.isEmpty, converted != stem, converted != stemKatakana
            else { continue }
            append(candidate)
        }
        append(Candidate(storageText: stem + okurigana, source: .automaticKana, reading: input))
        return appendingTyped(composition.typed, to: result, reading: input)
    }

    /// The keys as typed close the list, so a capitalized English word can
    /// still be entered with SKK mode on
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
