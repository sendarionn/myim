public struct LatencySampleSummary: Equatable, Sendable {
    public let count: Int
    public let totalMicroseconds: Int64
    public let p50Microseconds: Int64
    public let p95Microseconds: Int64
    public let p99Microseconds: Int64
    public let maximumMicroseconds: Int64
    public let slowSampleCount: Int
}

public struct LatencySampleWindow: Sendable {
    private let capacity: Int
    private let slowThresholdMicroseconds: Int64
    private var samples: [Int64] = []

    public init(capacity: Int, slowThresholdMicroseconds: Int64) {
        self.capacity = max(1, capacity)
        self.slowThresholdMicroseconds = slowThresholdMicroseconds
        samples.reserveCapacity(self.capacity)
    }

    public mutating func record(
        microseconds: Int64
    ) -> LatencySampleSummary? {
        samples.append(max(0, microseconds))
        guard samples.count == capacity else { return nil }

        let sorted = samples.sorted()
        let total = sorted.reduce(0, +)
        let summary = LatencySampleSummary(
            count: sorted.count,
            totalMicroseconds: total,
            p50Microseconds: percentile(0.50, in: sorted),
            p95Microseconds: percentile(0.95, in: sorted),
            p99Microseconds: percentile(0.99, in: sorted),
            maximumMicroseconds: sorted.last ?? 0,
            slowSampleCount: sorted.reduce(0) {
                $0 + ($1 >= slowThresholdMicroseconds ? 1 : 0)
            }
        )
        samples.removeAll(keepingCapacity: true)
        return summary
    }

    private func percentile(
        _ percentile: Double,
        in sorted: [Int64]
    ) -> Int64 {
        let index = Int(Double(sorted.count - 1) * percentile)
        return sorted[index]
    }
}
