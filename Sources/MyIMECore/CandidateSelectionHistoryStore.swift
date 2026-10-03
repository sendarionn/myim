import Foundation

public final class CandidateSelectionHistoryStore {
    private var history: CandidateSelectionHistory
    private let writer: DeferredJSONFileWriter<CandidateSelectionHistory>

    public init(
        history: CandidateSelectionHistory,
        writer: DeferredJSONFileWriter<CandidateSelectionHistory>
    ) {
        self.history = history
        self.writer = writer
    }

    public var snapshot: CandidateSelectionHistory {
        history
    }

    public func ranks(for reading: String) -> [String: Int] {
        history.ranks(for: reading)
    }

    public func ranks(for readings: [String]) -> [String: Int] {
        history.ranks(for: readings)
    }

    public func candidates(for readings: [String]) -> [String] {
        history.candidates(for: readings)
    }

    public func completions(
        for readingPrefix: String,
        limit: Int = 14
    ) -> [String] {
        history.completions(for: readingPrefix, limit: limit)
    }

    public func containsAny(_ candidates: Set<String>) -> Bool {
        candidates.contains { history.ranks[$0] != nil }
    }

    public func record(_ candidate: String, readings: [String]) {
        history.record(candidate, readings: readings)
        writer.schedule(history)
    }

    public func remove(_ candidates: Set<String>) {
        history.remove(candidates)
        writer.schedule(history)
    }

    public func flush() {
        writer.flush()
    }
}
