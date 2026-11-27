import Foundation

/// Candidates generated from the user's own words, as 検討した from 検討する
/// registered, that the user removed. They are made again on every
/// conversion, so they are left out by the reading they were removed from
/// and their text; the same text from another reading stays
public struct DerivedCandidateExclusions: Codable, Equatable, Sendable {
    /// Candidates by the reading they were removed from, as romaji in the
    /// canonical spelling, so tu and tsu are one reading
    public private(set) var candidatesByReading: [String: [String]] = [:]

    public init() {}

    public var isEmpty: Bool { candidatesByReading.isEmpty }

    public func contains(reading: String, candidate: String) -> Bool {
        candidatesByReading[Self.key(for: reading)]?.contains(candidate) == true
    }

    public mutating func insert(reading: String, candidate: String) {
        let key = Self.key(for: reading)
        guard candidatesByReading[key]?.contains(candidate) != true else { return }
        candidatesByReading[key, default: []].append(candidate)
    }

    /// A word registered again under the reading is shown again
    public mutating func remove(reading: String, candidate: String) {
        let key = Self.key(for: reading)
        candidatesByReading[key]?.removeAll { $0 == candidate }
        if candidatesByReading[key]?.isEmpty == true {
            candidatesByReading[key] = nil
        }
    }

    public func filtering(_ candidates: [Candidate], reading: String) -> [Candidate] {
        guard let excluded = candidatesByReading[Self.key(for: reading)] else { return candidates }
        return candidates.filter { !excluded.contains($0.storageText) }
    }

    private static func key(for reading: String) -> String {
        RomajiCanonicalizer.canonicalInput(from: reading.lowercased())
    }
}

/// Whether a candidate is made from a word the user registered: an
/// inflection of a base form whose reading and text are an entry of the
/// user dictionary
public enum DerivedCandidateOrigin {
    public static func isDerived(
        _ candidate: Candidate,
        fromUserEntries entries: [DictionaryEntry]
    ) -> Bool {
        let bases = candidate.origins.compactMap(\.inflectionBase)
        guard !bases.isEmpty else { return false }
        return bases.contains { base in
            let reading = RomajiCanonicalizer.canonicalInput(from: base.reading.lowercased())
            return entries.contains { entry in
                RomajiCanonicalizer.canonicalInput(from: entry.input.lowercased()) == reading
                    && entry.candidates.contains {
                        DictionaryCandidateRepresentation.value(from: $0) == base.surface
                    }
            }
        }
    }
}
