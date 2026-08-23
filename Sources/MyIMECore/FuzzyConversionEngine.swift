import Foundation

public struct FuzzyConversionMatch: Equatable, Sendable {
    public let reading: String
    public let candidates: [String]
    public let distance: Int

    public init(reading: String, candidates: [String], distance: Int) {
        self.reading = reading
        self.candidates = candidates
        self.distance = distance
    }
}

public struct FuzzyConversionEngine: Sendable {
    private struct IndexedEntry: Sendable {
        let reading: String
        let characters: [Character]
        let candidates: [String]
        let order: Int
    }

    private static let indexedMaximumDistance = 2
    private static let dictionaryOrderWeight = 0.32
    private let indexedEntries: [IndexedEntry]
    private let deletionIndex: SymmetricDeleteIndex
    private let entriesByReading: [String: IndexedEntry]

    public init(entries: [DictionaryEntry]) {
        var merged: [String: [String]] = [:]
        var readingOrder: [String] = []
        for entry in entries {
            let reading = RomajiCanonicalizer.canonicalInput(
                from: entry.input
            )
            guard !reading.isEmpty else {
                continue
            }
            if merged[reading] == nil {
                merged[reading] = []
                readingOrder.append(reading)
            }
            for candidate in entry.candidates
            where merged[reading]?.contains(candidate) == false {
                merged[reading]?.append(candidate)
            }
        }

        var entries: [IndexedEntry] = []
        var indexedByReading: [String: IndexedEntry] = [:]
        for (order, reading) in readingOrder.enumerated() {
            let canonicalEntry = IndexedEntry(
                reading: reading,
                characters: Array(reading),
                candidates: merged[reading] ?? [],
                order: order
            )
            indexedByReading[reading] = canonicalEntry
            for searchReading in Self.fuzzyReadingVariants(from: reading) {
                entries.append(
                    IndexedEntry(
                        reading: reading,
                        characters: Array(searchReading),
                        candidates: merged[reading] ?? [],
                        order: order
                    )
                )
            }
        }
        indexedEntries = entries
        deletionIndex = SymmetricDeleteIndex(
            terms: entries.map { String($0.characters) },
            maximumDistance: Self.indexedMaximumDistance
        )
        entriesByReading = indexedByReading
    }

    public func matches(
        for input: String,
        maximumDistance: Int? = nil,
        limit: Int = 3
    ) -> [FuzzyConversionMatch] {
        let reading = RomajiCanonicalizer.canonicalInput(from: input)
        let sourceReadings = Self.fuzzyReadingVariants(from: reading)
        let source = Array(reading)
        let allowedDistance = maximumDistance
            ?? Self.defaultMaximumDistance(forLength: source.count)
        guard !source.isEmpty, allowedDistance >= 0, limit > 0 else {
            return []
        }

        var bestMatches: [
            String: (IndexedEntry, Int, Int, Double, Double)
        ] = [:]
        let directCorrections = RomajiKeyboardTypoGenerator.corrections(
            for: reading
        ) + Self.adjacentTranspositions(in: reading)
        for correctedReading in directCorrections {
            let canonicalCorrection = RomajiCanonicalizer.canonicalInput(
                from: correctedReading
            )
            guard let entry = entriesByReading[canonicalCorrection],
                  entry.reading != reading else {
                continue
            }
            let typoCost = min(
                RomajiTypoScorer.cost(from: reading, to: entry.reading),
                RomajiTypoScorer.cost(from: reading, to: correctedReading)
            )
            bestMatches[entry.reading] = (
                entry,
                1,
                Self.commonPrefixLength(source, entry.characters),
                typoCost + Self.dictionaryOrderPenalty(entry.order),
                typoCost
            )
        }
        for sourceReading in sourceReadings {
            let sourceCharacters = Array(sourceReading)
            let identifiers = deletionIndex.candidateIdentifiers(
                for: sourceReading,
                maximumDistance: allowedDistance
            )
            for identifier in identifiers {
                let entry = indexedEntries[identifier]
                guard entry.reading != reading,
                      let distance = Self.damerauLevenshteinDistance(
                          sourceCharacters,
                          entry.characters,
                          maximumDistance: allowedDistance
                      ) else {
                    continue
                }
                let prefixLength = Self.commonPrefixLength(
                    sourceCharacters,
                    entry.characters
                )
                let typoCost = RomajiTypoScorer.cost(
                    from: sourceReading,
                    to: String(entry.characters)
                )
                let rankingCost = typoCost
                    + Self.dictionaryOrderPenalty(entry.order)
                if let current = bestMatches[entry.reading],
                   current.3 < rankingCost
                    || current.3 == rankingCost && current.1 < distance
                    || current.3 == rankingCost && current.1 == distance
                        && current.2 >= prefixLength {
                    continue
                }
                bestMatches[entry.reading] = (
                    entry,
                    distance,
                    prefixLength,
                    rankingCost,
                    typoCost
                )
            }
        }

        var matches = bestMatches.values.filter {
            $0.4 <= Self.maximumTypoCost(forLength: source.count)
        }
        matches.sort {
            if $0.3 != $1.3 {
                return $0.3 < $1.3
            }
            if $0.1 != $1.1 {
                return $0.1 < $1.1
            }
            if $0.2 != $1.2 {
                return $0.2 > $1.2
            }
            return $0.0.order < $1.0.order
        }
        return matches.prefix(limit).map {
            FuzzyConversionMatch(
                reading: $0.0.reading,
                candidates: $0.0.candidates,
                distance: $0.1
            )
        }
    }

    public static func defaultMaximumDistance(forLength length: Int) -> Int {
        switch length {
        case ..<4:
            0
        case 4...6:
            1
        default:
            2
        }
    }

    private static func dictionaryOrderPenalty(_ order: Int) -> Double {
        log1p(Double(order + 1)) * dictionaryOrderWeight
    }

    private static func maximumTypoCost(forLength length: Int) -> Double {
        switch length {
        case ..<4:
            0.5
        case 4...6:
            1
        default:
            1.25
        }
    }

    private static func fuzzyReadingVariants(from reading: String) -> [String] {
        var variants: [String] = []
        var seen = Set<String>()
        func append(_ value: String) {
            guard !value.isEmpty, seen.insert(value).inserted else {
                return
            }
            variants.append(value)
        }

        let moraicN = collapsedMoraicN(in: reading)
        let apostrophe = reading.replacingOccurrences(of: "n'", with: "n")
        let nasal = normalizedLabialNasal(in: reading)
        let longVowels = normalizedLongVowels(in: reading)
        append(reading)
        append(moraicN)
        append(apostrophe)
        append(nasal)
        append(longVowels)
        append(normalizedLongVowels(in: moraicN))
        append(normalizedLongVowels(in: apostrophe))
        append(normalizedLongVowels(in: nasal))
        append(normalizedLabialNasal(in: moraicN))
        return variants
    }

    private static func collapsedMoraicN(in reading: String) -> String {
        let characters = Array(reading)
        guard characters.count >= 2 else {
            return reading
        }
        var collapsed = ""
        var index = 0
        while index < characters.count {
            if characters[index] == "n",
               index + 1 < characters.count,
               characters[index + 1] == "n",
               index + 2 == characters.count
                || "aeiou".contains(characters[index + 2]) {
                collapsed.append("n")
                index += 2
                continue
            }
            collapsed.append(characters[index])
            index += 1
        }
        return collapsed
    }

    private static func normalizedLabialNasal(in reading: String) -> String {
        let characters = Array(reading)
        guard characters.count >= 2 else {
            return reading
        }
        var normalized = characters
        for index in 0..<(characters.count - 1)
        where characters[index] == "m"
            && "bmp".contains(characters[index + 1]) {
            normalized[index] = "n"
        }
        return String(normalized)
    }

    private static func normalizedLongVowels(in reading: String) -> String {
        let characters = Array(reading)
        guard characters.count >= 2 else {
            return reading
        }
        var normalized = ""
        var index = 0
        while index < characters.count {
            let current = characters[index]
            normalized.append(current)
            guard index + 1 < characters.count else {
                break
            }
            let next = characters[index + 1]
            let isLongVowel = current == next && "aeiou".contains(current)
                || current == "o" && next == "u"
                || current == "e" && next == "i"
            index += isLongVowel ? 2 : 1
        }
        return normalized
    }

    private static func commonPrefixLength(
        _ left: [Character],
        _ right: [Character]
    ) -> Int {
        zip(left, right).prefix { $0 == $1 }.count
    }

    private static func adjacentTranspositions(in input: String) -> [String] {
        let characters = Array(input)
        guard characters.count >= 2 else { return [] }
        return (0..<(characters.count - 1)).compactMap { index in
            guard characters[index] != characters[index + 1] else {
                return nil
            }
            var transposed = characters
            transposed.swapAt(index, index + 1)
            return String(transposed)
        }
    }

    private static func damerauLevenshteinDistance(
        _ source: [Character],
        _ target: [Character],
        maximumDistance: Int
    ) -> Int? {
        guard abs(source.count - target.count) <= maximumDistance else {
            return nil
        }
        if source.isEmpty {
            return target.count <= maximumDistance ? target.count : nil
        }
        if target.isEmpty {
            return source.count <= maximumDistance ? source.count : nil
        }

        var previousPrevious = [Int](repeating: 0, count: target.count + 1)
        var previous = Array(0...target.count)
        for sourceIndex in 1...source.count {
            var current = [Int](repeating: 0, count: target.count + 1)
            current[0] = sourceIndex
            var rowMinimum = current[0]
            for targetIndex in 1...target.count {
                let substitutionCost = source[sourceIndex - 1]
                    == target[targetIndex - 1] ? 0 : 1
                current[targetIndex] = min(
                    previous[targetIndex] + 1,
                    current[targetIndex - 1] + 1,
                    previous[targetIndex - 1] + substitutionCost
                )
                if sourceIndex > 1,
                   targetIndex > 1,
                   source[sourceIndex - 1] == target[targetIndex - 2],
                   source[sourceIndex - 2] == target[targetIndex - 1] {
                    current[targetIndex] = min(
                        current[targetIndex],
                        previousPrevious[targetIndex - 2] + 1
                    )
                }
                rowMinimum = min(rowMinimum, current[targetIndex])
            }
            if rowMinimum > maximumDistance {
                return nil
            }
            previousPrevious = previous
            previous = current
        }
        return previous[target.count] <= maximumDistance
            ? previous[target.count]
            : nil
    }
}
