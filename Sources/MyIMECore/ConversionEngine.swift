import Foundation

public struct ConversionEngine: Sendable {
    private let candidatesByReading: [String: [String]]
    private let entries: [DictionaryEntry]

    public init(entries: [DictionaryEntry]) {
        self.init(layers: [entries])
    }

    public init(layers: [[DictionaryEntry]]) {
        var readingOrder: [String] = []
        var mergedCandidates: [String: [String]] = [:]

        for layer in layers {
            for entry in layer {
                if mergedCandidates[entry.reading] == nil {
                    readingOrder.append(entry.reading)
                    mergedCandidates[entry.reading] = []
                }

                for candidate in entry.candidates
                where mergedCandidates[entry.reading]?.contains(candidate) == false {
                    mergedCandidates[entry.reading]?.append(candidate)
                }
            }
        }

        self.entries = readingOrder.map {
            DictionaryEntry(
                reading: $0,
                candidates: mergedCandidates[$0] ?? []
            )
        }
        self.candidatesByReading = mergedCandidates
    }

    public func candidates(for reading: String) -> [String] {
        candidatesByReading[reading] ?? []
    }

    public func candidates(
        matching readingPrefix: String,
        limit: Int = .max
    ) -> [String] {
        guard !readingPrefix.isEmpty, limit > 0 else {
            return []
        }

        var seen = Set<String>()
        var result: [String] = []

        if let exactCandidates = candidatesByReading[readingPrefix] {
            for candidate in exactCandidates where seen.insert(candidate).inserted {
                result.append(candidate)
                if result.count == limit {
                    return result
                }
            }
        }

        for entry in entries
        where entry.reading != readingPrefix
            && entry.reading.hasPrefix(readingPrefix) {
            for candidate in entry.candidates where seen.insert(candidate).inserted {
                result.append(candidate)
                if result.count == limit {
                    return result
                }
            }
        }

        return result
    }
}
