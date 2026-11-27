import Foundation

/// English words for Japanese readings, from the bundled dictionary made
/// from TKGJE's glosses (`Scripts/convert-tkgje-english-dictionary.py`), as
/// ringo for apple. Only the words in it are offered, never a guess
public struct JapaneseEnglishDictionary: Sendable {
    private let wordsByReading: [String: [String]]

    /// Lines of a reading and a word, separated by a tab
    public init(text: String) {
        var words: [String: [String]] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: "\t", maxSplits: 1)
            guard fields.count == 2 else { continue }
            let reading = RomajiCanonicalizer.canonicalInput(from: String(fields[0]))
            let word = String(fields[1])
            if words[reading]?.contains(word) != true {
                words[reading, default: []].append(word)
            }
        }
        wordsByReading = words
    }

    public var isEmpty: Bool { wordsByReading.isEmpty }

    /// The English words for exactly the reading typed
    public func words(for reading: String) -> [String] {
        var found: [String] = []
        for lookup in RomajiCanonicalizer.dictionaryLookupInputs(from: reading) {
            for word in wordsByReading[RomajiCanonicalizer.canonicalInput(from: lookup)] ?? []
            where !found.contains(word) {
                found.append(word)
            }
        }
        return found
    }
}
