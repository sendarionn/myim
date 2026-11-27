import Foundation

/// A word a candidate is made from: the base form of an inflection, as
/// 検討する of 検討した, or the word before the particle of a composition,
/// as 私 of 私は, with the romaji reading it was found by
public struct CandidateBaseWord: Equatable, Hashable, Sendable {
    public let reading: String
    public let surface: String

    public init(reading: String, surface: String) {
        self.reading = reading
        self.surface = surface
    }
}

/// The user dictionary entries a candidate is made from, found by the
/// reading and the text of the word it is made from, never by its own text
public enum DerivedCandidateOrigin {
    public struct SourceEntry: Equatable, Hashable, Sendable {
        /// The entry's reading and candidate as stored, to remove it by
        public let reading: String
        public let candidate: String
    }

    public static func sourceEntries(
        of candidate: Candidate,
        in entries: [DictionaryEntry]
    ) -> [SourceEntry] {
        let words = candidate.origins.flatMap { origin in
            origin.baseWords + (origin.inflectionBase.map {
                [CandidateBaseWord(reading: $0.reading, surface: $0.surface)]
            } ?? [])
        }
        var found: [SourceEntry] = []
        for word in words {
            let reading = RomajiCanonicalizer.canonicalInput(from: word.reading.lowercased())
            for entry in entries
            where RomajiCanonicalizer.canonicalInput(from: entry.input.lowercased()) == reading {
                for stored in entry.candidates
                where DictionaryCandidateRepresentation.value(from: stored) == word.surface {
                    let source = SourceEntry(reading: entry.input, candidate: stored)
                    if !found.contains(source) {
                        found.append(source)
                    }
                }
            }
        }
        return found
    }
}
