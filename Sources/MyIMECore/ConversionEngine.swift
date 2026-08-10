import Foundation

public struct ConversionEngine: Sendable {
    private let candidatesByReading: [String: [String]]
    private let sortedReadings: [String]

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

        self.candidatesByReading = mergedCandidates
        self.sortedReadings = readingOrder.sorted()
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

        var index = lowerBound(of: normalizedPrefix)
        while index < sortedReadings.count,
              sortedReadings[index].hasPrefix(normalizedPrefix) {
            let reading = sortedReadings[index]
            if reading != normalizedPrefix {
                for candidate in candidatesByReading[reading] ?? []
                where seen.insert(candidate).inserted {
                    result.append(candidate)
                    if result.count == limit {
                        return result
                    }
                }
            }
            index += 1
        }

        return result
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
