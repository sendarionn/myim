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

    public func ranks(for reading: String) -> [String: Int] {
        guard let stats = statsByReading[reading.lowercased()], !stats.isEmpty,
              let mostRecent = stats.max(by: {
                  $0.value.lastUsed < $1.value.lastUsed
              }) else {
            return ranks
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
