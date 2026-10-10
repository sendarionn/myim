import Testing
@testable import MyIMECore

struct LatencySampleWindowTests {
    @Test
    func reportsBoundedDistributionWithoutRetainingOldSamples() throws {
        var window = LatencySampleWindow(
            capacity: 5,
            slowThresholdMicroseconds: 50_000
        )

        #expect(window.record(microseconds: 10_000) == nil)
        #expect(window.record(microseconds: 20_000) == nil)
        #expect(window.record(microseconds: 30_000) == nil)
        #expect(window.record(microseconds: 60_000) == nil)
        let recorded = window.record(microseconds: 100_000)
        let summary = try #require(recorded)

        #expect(summary.count == 5)
        #expect(summary.totalMicroseconds == 220_000)
        #expect(summary.p50Microseconds == 30_000)
        #expect(summary.p95Microseconds == 60_000)
        #expect(summary.p99Microseconds == 60_000)
        #expect(summary.maximumMicroseconds == 100_000)
        #expect(summary.slowSampleCount == 2)
        #expect(window.record(microseconds: 1_000) == nil)
    }
}
