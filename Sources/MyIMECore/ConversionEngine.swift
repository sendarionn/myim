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
                let input = entry.input.lowercased()
                if mergedCandidates[input] == nil {
                    readingOrder.append(input)
                    mergedCandidates[input] = []
                }

                for candidate in entry.candidates
                where mergedCandidates[input]?.contains(candidate) == false {
                    mergedCandidates[input]?.append(candidate)
                    if reverseReadings[candidate]?.contains(input) != true {
                        reverseReadings[candidate, default: []].append(input)
                    }
                }
            }
        }

        self.candidatesByReading = mergedCandidates
        self.sortedReadings = readingOrder.sorted()
        self.readingsByCandidate = reverseReadings
    }

    public func candidates(for reading: String) -> [String] {
        candidateGroups(matching: reading).exact
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
        let rawInput = readingPrefix.lowercased()
        guard !rawInput.isEmpty, limit > 0 else {
            return DictionaryCandidateGroups()
        }

        let lookupInputs = RomajiCanonicalizer.exactLookupInputs(
            from: rawInput
        )
        var seen = Set<String>()
        var exact: [String] = []
        var prefix: [String] = []

        for input in lookupInputs {
            if let exactCandidates = candidatesByReading[input] {
                for candidate in exactCandidates
                where seen.insert(candidate).inserted {
                    exact.append(candidate)
                    if exact.count == limit {
                        return DictionaryCandidateGroups(exact: exact)
                    }
                }
            }
        }

        for input in lookupInputs {
            var index = lowerBound(of: input)
            while index < sortedReadings.count,
                  sortedReadings[index].hasPrefix(input) {
                let storedInput = sortedReadings[index]
                if storedInput != input {
                    for candidate in candidatesByReading[storedInput] ?? []
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
