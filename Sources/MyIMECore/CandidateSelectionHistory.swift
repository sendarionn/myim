import Foundation

public struct CandidateSelectionHistory: Equatable, Codable, Sendable {
    public struct Stat: Equatable, Codable, Sendable {
        public var count: Int
        public var lastUsed: Int
    }

    public private(set) var ranks: [String: Int]
    private var statsByReading: [String: [String: Stat]]
    private var maximumEntryCount: Int?
    private var nextRank: Int

    public init(
        ranks: [String: Int] = [:],
        maximumEntryCount: Int? = nil
    ) {
        self.maximumEntryCount = maximumEntryCount.map { max(1, $0) }
        let recentRanks = Self.compacted(
            ranks,
            limit: self.maximumEntryCount
        )
        self.ranks = recentRanks
        statsByReading = [:]
        self.nextRank = (recentRanks.values.max() ?? 0) + 1
    }

    public mutating func record(_ candidate: String, reading: String? = nil) {
        guard !candidate.isEmpty else {
            return
        }
        ranks[candidate] = nextRank
        if let reading = reading?.lowercased(), !reading.isEmpty {
            var readingStats = statsByReading[reading] ?? [:]
            var stat = readingStats[candidate]
                ?? Stat(count: 0, lastUsed: nextRank)
            stat.count = min(stat.count + 1, Int.max - 1)
            stat.lastUsed = nextRank
            readingStats[candidate] = stat
            statsByReading[reading] = readingStats
        }
        nextRank += 1
        if let maximumEntryCount, ranks.count > maximumEntryCount {
            ranks = Self.compacted(ranks, limit: maximumEntryCount)
            nextRank = (ranks.values.max() ?? 0) + 1
        }
    }

    public mutating func remove(_ candidates: Set<String>) {
        guard !candidates.isEmpty else { return }
        for candidate in candidates {
            ranks.removeValue(forKey: candidate)
        }
        for reading in Array(statsByReading.keys) {
            var stats = statsByReading[reading] ?? [:]
            for candidate in candidates {
                stats.removeValue(forKey: candidate)
            }
            if stats.isEmpty {
                statsByReading.removeValue(forKey: reading)
            } else {
                statsByReading[reading] = stats
            }
        }
    }

    public func ranks(for reading: String) -> [String: Int] {
        guard let stats = statsByReading[reading.lowercased()], !stats.isEmpty,
              let mostRecent = stats.max(by: {
                  $0.value.lastUsed < $1.value.lastUsed
              }) else {
            return [:]
        }
        let ordered = [mostRecent] + stats
            .filter { $0.key != mostRecent.key }
            .sorted {
                if $0.value.count != $1.value.count {
                    return $0.value.count > $1.value.count
                }
                if $0.value.lastUsed != $1.value.lastUsed {
                    return $0.value.lastUsed > $1.value.lastUsed
                }
                return $0.key < $1.key
            }
        return Dictionary(uniqueKeysWithValues: ordered.enumerated().map {
            ($0.element.key, ordered.count - $0.offset)
        })
    }

    public func completions(for readingPrefix: String, limit: Int = 14) -> [String] {
        let prefix = readingPrefix.lowercased()
        guard prefix.count >= 2, limit > 0 else { return [] }
        var bestScores: [String: Double] = [:]
        for (reading, candidates) in statsByReading
        where reading != prefix && reading.hasPrefix(prefix) {
            let remainingLength = reading.count - prefix.count
            for (candidate, stat) in candidates {
                let age = max(nextRank - stat.lastUsed, 1)
                let score = log1p(Double(stat.count)) * 4
                    + 2 / log2(Double(age) + 2)
                    - Double(remainingLength) * 0.6
                bestScores[candidate] = max(bestScores[candidate] ?? -.infinity, score)
            }
        }
        return bestScores.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key < $1.key
        }.prefix(limit).map(\.key)
    }

    private static func compacted(
        _ ranks: [String: Int],
        limit: Int?
    ) -> [String: Int] {
        guard let limit, ranks.count > limit else { return ranks }
        let recent = ranks.sorted {
            $0.value == $1.value
                ? $0.key < $1.key
                : $0.value > $1.value
        }.prefix(limit)
        return Dictionary(uniqueKeysWithValues: recent.enumerated().map {
            ($0.element.key, recent.count - $0.offset)
        })
    }
}
