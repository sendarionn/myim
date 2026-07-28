import Foundation

public struct ConversionEngine: Sendable {
    private let candidatesByReading: [String: [String]]
    private let entries: [DictionaryEntry]

    public init(entries: [DictionaryEntry]) {
        self.entries = entries
        self.candidatesByReading = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.reading, $0.candidates) }
        )
    }

    public func candidates(for reading: String) -> [String] {
        candidatesByReading[reading] ?? []
    }

    public func candidates(matching readingPrefix: String) -> [String] {
        guard !readingPrefix.isEmpty else {
            return []
        }

        var seen = Set<String>()
        var result: [String] = []

        if let exactCandidates = candidatesByReading[readingPrefix] {
            for candidate in exactCandidates where seen.insert(candidate).inserted {
                result.append(candidate)
            }
        }

        for entry in entries
        where entry.reading != readingPrefix
            && entry.reading.hasPrefix(readingPrefix) {
            for candidate in entry.candidates where seen.insert(candidate).inserted {
                result.append(candidate)
            }
        }

        return result
    }
}
