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

    private let entriesByLength: [Int: [IndexedEntry]]

    public init(entries: [DictionaryEntry]) {
        var merged: [String: [String]] = [:]
        var readingOrder: [String] = []
        for entry in entries {
            let reading = RomanizedReadingNormalizer.dictionaryReading(
                from: entry.reading
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

        var buckets: [Int: [IndexedEntry]] = [:]
        for (order, reading) in readingOrder.enumerated() {
            let characters = Array(reading)
            buckets[characters.count, default: []].append(
                IndexedEntry(
                    reading: reading,
                    characters: characters,
                    candidates: merged[reading] ?? [],
                    order: order
                )
            )
        }
        entriesByLength = buckets
    }

    public func matches(
        for input: String,
        maximumDistance: Int? = nil,
        limit: Int = 3
    ) -> [FuzzyConversionMatch] {
        let reading = RomanizedReadingNormalizer.dictionaryReading(from: input)
        let source = Array(reading)
        let allowedDistance = maximumDistance
            ?? Self.defaultMaximumDistance(forLength: source.count)
        guard !source.isEmpty, allowedDistance > 0, limit > 0 else {
            return []
        }

        var matches: [(IndexedEntry, Int, Int)] = []
        let minimumLength = max(1, source.count - allowedDistance)
        let maximumLength = source.count + allowedDistance
        for length in minimumLength...maximumLength {
            for entry in entriesByLength[length] ?? [] where entry.reading != reading {
                guard let distance = Self.damerauLevenshteinDistance(
                    source,
                    entry.characters,
                    maximumDistance: allowedDistance
                ) else {
                    continue
                }
                matches.append((
                    entry,
                    distance,
                    Self.commonPrefixLength(source, entry.characters)
                ))
            }
        }

        matches.sort {
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
        case 4...7:
            1
        default:
            2
        }
    }

    private static func commonPrefixLength(
        _ left: [Character],
        _ right: [Character]
    ) -> Int {
        zip(left, right).prefix { $0 == $1 }.count
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
