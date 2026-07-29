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
                let normalizedReading =
                    RomanizedReadingNormalizer.dictionaryReading(
                        from: entry.reading
                    )
                if mergedCandidates[normalizedReading] == nil {
                    readingOrder.append(normalizedReading)
                    mergedCandidates[normalizedReading] = []
                }

                for candidate in entry.candidates
                where mergedCandidates[normalizedReading]?.contains(candidate) == false {
                    mergedCandidates[normalizedReading]?.append(candidate)
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
        let normalizedReading =
            RomanizedReadingNormalizer.dictionaryReading(from: reading)
        return candidatesByReading[normalizedReading] ?? []
    }

    public func candidates(
        matching readingPrefix: String,
        limit: Int = .max
    ) -> [String] {
        let normalizedPrefix =
            RomanizedReadingNormalizer.dictionaryReading(from: readingPrefix)
        guard !normalizedPrefix.isEmpty, limit > 0 else {
            return []
        }

        var seen = Set<String>()
        var result: [String] = []

        if let exactCandidates = candidatesByReading[normalizedPrefix] {
            for candidate in exactCandidates where seen.insert(candidate).inserted {
                result.append(candidate)
                if result.count == limit {
                    return result
                }
            }
        }

        for entry in entries
        where entry.reading != normalizedPrefix
            && entry.reading.hasPrefix(normalizedPrefix) {
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
