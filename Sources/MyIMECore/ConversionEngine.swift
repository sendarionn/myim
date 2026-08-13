import Foundation

public struct ConversionEngine: Sendable {
    private let candidatesByReading: [String: [String]]
    private let sortedReadings: [String]
    private let readingsByCandidate: [String: [String]]

    public init(entries: [DictionaryEntry]) {
        self.init(layers: [entries])
    }

    public init(layers: [[DictionaryEntry]]) {
        var readingOrder: [String] = []
        var mergedCandidates: [String: [String]] = [:]
        var reverseReadings: [String: [String]] = [:]

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
                    if reverseReadings[candidate]?.contains(normalizedReading) != true {
                        reverseReadings[candidate, default: []].append(normalizedReading)
                    }
                }
            }
        }

        self.candidatesByReading = mergedCandidates
        self.sortedReadings = readingOrder.sorted()
        self.readingsByCandidate = reverseReadings
    }

    public func candidates(for reading: String) -> [String] {
        let normalizedReading =
            RomanizedReadingNormalizer.dictionaryReading(from: reading)
        return candidatesByReading[normalizedReading] ?? []
    }

    public func readings(for candidate: String) -> [String] {
        readingsByCandidate[candidate] ?? []
    }

    public func candidates(
        matching readingPrefix: String,
        limit: Int = .max
    ) -> [String] {
        candidateGroups(matching: readingPrefix, limit: limit).all
    }

    public func candidateGroups(
        matching readingPrefix: String,
        limit: Int = .max
    ) -> DictionaryCandidateGroups {
        let normalizedPrefix =
            RomanizedReadingNormalizer.dictionaryReading(from: readingPrefix)
        guard !normalizedPrefix.isEmpty, limit > 0 else {
            return DictionaryCandidateGroups()
        }

        var seen = Set<String>()
        var exact: [String] = []
        var prefix: [String] = []

        if let exactCandidates = candidatesByReading[normalizedPrefix] {
            for candidate in exactCandidates where seen.insert(candidate).inserted {
                exact.append(candidate)
                if exact.count == limit {
                    return DictionaryCandidateGroups(exact: exact)
                }
            }
        }

        var index = lowerBound(of: normalizedPrefix)
        while index < sortedReadings.count,
              sortedReadings[index].hasPrefix(normalizedPrefix) {
            let reading = sortedReadings[index]
            if reading != normalizedPrefix {
                for candidate in candidatesByReading[reading] ?? []
                where seen.insert(candidate).inserted {
                    prefix.append(candidate)
                    if exact.count + prefix.count == limit {
                        return DictionaryCandidateGroups(
                            exact: exact,
                            prefix: prefix
                        )
                    }
                }
            }
            index += 1
        }

        return DictionaryCandidateGroups(exact: exact, prefix: prefix)
    }

    private func lowerBound(of value: String) -> Int {
        var lower = 0
        var upper = sortedReadings.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if sortedReadings[middle] < value {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }
}
