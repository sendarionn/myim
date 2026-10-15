public struct UnselectedInputLearningHistory: Equatable, Codable, Sendable {
    public static let defaultMaximumEntryCount = 10_000

    private struct Stat: Equatable, Codable, Sendable {
        var count: Int
        var lastUsed: Int
    }

    private var statsByCandidate: [String: Stat]
    private var sequence: Int
    private var maximumEntryCount: Int

    public init(
        maximumEntryCount: Int = defaultMaximumEntryCount
    ) {
        statsByCandidate = [:]
        sequence = 0
        self.maximumEntryCount = max(1, maximumEntryCount)
    }

    var trackedCandidateCount: Int {
        statsByCandidate.count
    }

    func confirmationCount(for candidate: String) -> Int {
        statsByCandidate[candidate]?.count ?? 0
    }

    public mutating func registration(
        after entry: UnselectedInputLearningEntry
    ) -> UnselectedInputLearningEntry? {
        guard UnselectedInputLearningPolicy.requiresRepeatedConfirmation(
            entry.candidate
        ) else {
            return entry
        }
        sequence = min(sequence + 1, Int.max - 1)
        var stat = statsByCandidate[entry.candidate]
            ?? Stat(count: 0, lastUsed: sequence)
        stat.count = min(stat.count + 1, 2)
        stat.lastUsed = sequence
        statsByCandidate[entry.candidate] = stat
        compactIfNeeded()
        return stat.count >= 2 ? entry : nil
    }

    public mutating func markRegistered(candidate: String) {
        guard UnselectedInputLearningPolicy.requiresRepeatedConfirmation(
            candidate
        ) else {
            return
        }
        sequence = min(sequence + 1, Int.max - 1)
        statsByCandidate[candidate] = Stat(count: 2, lastUsed: sequence)
        compactIfNeeded()
    }

    public mutating func remove(candidate: String) {
        statsByCandidate.removeValue(forKey: candidate)
    }

    private mutating func compactIfNeeded() {
        guard statsByCandidate.count > maximumEntryCount else { return }
        let retained = statsByCandidate.sorted {
            if $0.value.lastUsed != $1.value.lastUsed {
                return $0.value.lastUsed > $1.value.lastUsed
            }
            return $0.key < $1.key
        }.prefix(maximumEntryCount)
        statsByCandidate = Dictionary(uniqueKeysWithValues: retained.map {
            ($0.key, $0.value)
        })
    }

    private enum CodingKeys: String, CodingKey {
        case statsByCandidate
        case sequence
        case maximumEntryCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        statsByCandidate = try container.decodeIfPresent(
            [String: Stat].self,
            forKey: .statsByCandidate
        ) ?? [:]
        sequence = try container.decodeIfPresent(Int.self, forKey: .sequence)
            ?? 0
        maximumEntryCount = max(
            1,
            try container.decodeIfPresent(
                Int.self,
                forKey: .maximumEntryCount
            ) ?? Self.defaultMaximumEntryCount
        )
        compactIfNeeded()
    }
}

public final class UnselectedInputLearningStore {
    private var history: UnselectedInputLearningHistory
    private let writer: DeferredJSONFileWriter<UnselectedInputLearningHistory>

    public init(
        history: UnselectedInputLearningHistory,
        writer: DeferredJSONFileWriter<UnselectedInputLearningHistory>
    ) {
        self.history = history
        self.writer = writer
    }

    public func registration(
        after entry: UnselectedInputLearningEntry
    ) -> UnselectedInputLearningEntry? {
        guard UnselectedInputLearningPolicy.requiresRepeatedConfirmation(
            entry.candidate
        ) else {
            return entry
        }
        let registration = history.registration(after: entry)
        writer.schedule(history)
        return registration
    }

    public func markRegistered(candidate: String) {
        guard UnselectedInputLearningPolicy.requiresRepeatedConfirmation(
            candidate
        ) else {
            return
        }
        history.markRegistered(candidate: candidate)
        writer.schedule(history)
    }

    public func remove(candidate: String) {
        history.remove(candidate: candidate)
        writer.schedule(history)
    }

    public func flush() {
        writer.flush()
    }
}
