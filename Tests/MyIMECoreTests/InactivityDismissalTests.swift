import Foundation
import Testing
@testable import MyIMECore

/// The next-input panel closes five seconds after the last operation on
/// it, whatever arrives in the background meanwhile
@Suite
struct InactivityDismissalTests {
    @Test
    func closesAfterTheIntervalWithoutOperations() {
        let clock = ManualClock()
        let dismissal = clock.dismissal(interval: 5)
        var closed = 0

        dismissal.restart { closed += 1 }
        clock.advance(by: 4.9)
        #expect(closed == 0)
        clock.advance(by: 0.1)

        #expect(closed == 1)
        #expect(!dismissal.isScheduled)
    }

    @Test
    func eachOperationCountsTheIntervalAgain() {
        let clock = ManualClock()
        let dismissal = clock.dismissal(interval: 5)
        var closed = 0

        dismissal.restart { closed += 1 }
        for _ in 0..<3 {
            clock.advance(by: 4)
            dismissal.restart { closed += 1 }
        }
        clock.advance(by: 4.9)
        #expect(closed == 0)
        clock.advance(by: 0.1)

        #expect(closed == 1)
    }

    @Test
    func backgroundResultsDoNotExtendTheCountdown() {
        let clock = ManualClock()
        let dismissal = clock.dismissal(interval: 5)
        var closed = 0

        dismissal.restart { closed += 1 }
        clock.advance(by: 3)
        dismissal.startIfIdle { closed += 1 }
        clock.advance(by: 2)

        #expect(closed == 1)
    }

    @Test
    func backgroundResultStartsTheCountdownForAPanelWithoutOne() {
        let clock = ManualClock()
        let dismissal = clock.dismissal(interval: 5)
        var closed = 0

        dismissal.startIfIdle { closed += 1 }
        clock.advance(by: 5)

        #expect(closed == 1)
    }

    @Test
    func cancelledCountdownNeverCloses() {
        let clock = ManualClock()
        let dismissal = clock.dismissal(interval: 5)
        var closed = 0

        dismissal.restart { closed += 1 }
        dismissal.cancel()
        clock.advance(by: 10)

        #expect(closed == 0)
    }

    @Test
    func replacedCountdownFiringLateIsIgnored() {
        // The platform timer may already be due when it is invalidated
        let clock = ManualClock(ignoresCancellation: true)
        let dismissal = clock.dismissal(interval: 5)
        var closed: [String] = []

        dismissal.restart { closed.append("first") }
        clock.advance(by: 4)
        dismissal.restart { closed.append("second") }
        clock.advance(by: 1)
        #expect(closed.isEmpty)
        clock.advance(by: 4)

        #expect(closed == ["second"])
    }
}

/// Fires scheduled actions as time is advanced by hand
private final class ManualClock {
    private struct Pending {
        let id: Int
        let deadline: TimeInterval
        let action: () -> Void
    }

    private let ignoresCancellation: Bool
    private var now: TimeInterval = 0
    private var nextID = 0
    private var pending: [Pending] = []

    init(ignoresCancellation: Bool = false) {
        self.ignoresCancellation = ignoresCancellation
    }

    func dismissal(interval: TimeInterval) -> InactivityDismissal {
        InactivityDismissal(interval: interval) { [unowned self] in
            schedule(after: $0, $1)
        }
    }

    func advance(by interval: TimeInterval) {
        now += interval
        while let next = pending
            .filter({ $0.deadline <= now + 1e-9 })
            .min(by: { $0.deadline < $1.deadline }) {
            pending.removeAll { $0.id == next.id }
            next.action()
        }
    }

    private func schedule(
        after interval: TimeInterval,
        _ action: @escaping () -> Void
    ) -> () -> Void {
        nextID += 1
        let id = nextID
        pending.append(Pending(id: id, deadline: now + interval, action: action))
        return { [unowned self] in
            guard !ignoresCancellation else { return }
            pending.removeAll { $0.id == id }
        }
    }
}
