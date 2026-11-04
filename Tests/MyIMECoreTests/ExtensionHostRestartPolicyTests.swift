import Testing
@testable import MyIMECore

@Suite
struct ExtensionHostRestartPolicyTests {
    @Test
    func pausesAfterRepeatedTimeoutsAndResumesLater() {
        var policy = ExtensionHostRestartPolicy(
            maximumTimeouts: 3,
            window: 30,
            pause: 30
        )

        let first = policy.recordTimeout(now: 1)
        let second = policy.recordTimeout(now: 2)
        #expect(!first && !second)
        #expect(policy.allowsRequest(now: 2))
        let third = policy.recordTimeout(now: 3)
        #expect(third)

        #expect(!policy.allowsRequest(now: 4))
        #expect(!policy.allowsRequest(now: 32))
        #expect(policy.allowsRequest(now: 33))
    }

    @Test
    func occasionalTimeoutsDoNotPause() {
        var policy = ExtensionHostRestartPolicy(
            maximumTimeouts: 3,
            window: 30,
            pause: 30
        )

        let paused = [1.0, 40, 80].map { policy.recordTimeout(now: $0) }
        #expect(paused == [false, false, false])
        #expect(policy.allowsRequest(now: 81))
    }

    @Test
    func aResponseClearsTheCount() {
        var policy = ExtensionHostRestartPolicy(
            maximumTimeouts: 3,
            window: 30,
            pause: 30
        )
        policy.recordTimeout(now: 1)
        policy.recordTimeout(now: 2)

        policy.recordResponse()

        let paused = policy.recordTimeout(now: 3)
        #expect(!paused)
        #expect(policy.allowsRequest(now: 3))
    }
}

@Suite
struct MainThreadStallClassifierTests {
    @Test(arguments: [
        (3_000, 100, MainThreadStallKind.mainThreadOnly),
        (6_000, 3_000, MainThreadStallKind.processOrSystemWide),
        (1_000, 250, MainThreadStallKind.processOrSystemWide),
        (1_000, 249, MainThreadStallKind.mainThreadOnly)
    ])
    func tellsAMainThreadHeldUpFromAWholeSlowdown(
        stall: Int,
        lateness: Int,
        kind: MainThreadStallKind
    ) {
        #expect(MainThreadStallClassifier.classify(
            stallMilliseconds: stall,
            latestTimerLatenessMilliseconds: lateness
        ) == kind)
    }
}
