import Testing
@testable import MyIMECore

@Suite
struct InputLocationAnchorSessionTests {
    @Test
    func adoptsTheCurrentLocationAsCompositionAnchor() {
        var session = InputLocationAnchorSession<Int>()

        let anchor = session.candidateAnchor(after: .accepted(10))

        #expect(anchor == .current(10))
        #expect(session.compositionAnchor == 10)
        #expect(session.lastValidLocation == 10)
    }

    @Test
    func defersTheCandidatePanelAfterRejectingAPlaceholder() {
        var session = InputLocationAnchorSession<Int>()
        session.captureCompositionAnchor(.accepted(10))

        let anchor = session.candidateAnchor(after: .rejectedPlaceholder)

        #expect(anchor == .deferredAfterPlaceholder)
        #expect(anchor.location == nil)
        #expect(anchor.shouldRetry)
    }

    @Test
    func fallsBackToTheCompositionAnchorBeforeThePreviousLocation() {
        var session = InputLocationAnchorSession<Int>()
        session.captureCompositionAnchor(.accepted(10))
        session.record(.accepted(20))

        #expect(session.candidateAnchor(after: .unavailable) == .composition(10))

        session.clearCompositionAnchor()

        #expect(session.candidateAnchor(after: .unavailable) == .previous(20))
    }

    @Test
    func reportsAMissingAnchorWithoutRetrying() {
        var session = InputLocationAnchorSession<Int>()

        let anchor = session.candidateAnchor(after: .unavailable)

        #expect(anchor == .missing)
        #expect(!anchor.shouldRetry)
    }

    @Test
    func capturesNoCompositionAnchorWhenTheLocationIsUnavailable() {
        var session = InputLocationAnchorSession<Int>()
        session.captureCompositionAnchor(.accepted(10))

        session.captureCompositionAnchor(.unavailable)

        #expect(session.compositionAnchor == nil)
        #expect(session.lastValidLocation == 10)
    }

    @Test
    func reusesThePreviousLocationUntilANewActivationForgetsIt() {
        var session = InputLocationAnchorSession<Int>()

        #expect(session.fallbackLocation(after: .accepted(10)) == 10)
        #expect(session.fallbackLocation(after: .rejectedPlaceholder) == 10)

        session.forgetPreviousLocation()

        #expect(session.fallbackLocation(after: .unavailable) == nil)
    }

    @Test
    func backsOffRetryDelayByAttemptAndResets() {
        var session = InputLocationAnchorSession<Int>()
        #expect(session.nextRetryDelay == 0.04)

        for _ in 0..<10 {
            session.beginRetryAttempt()
        }

        #expect(session.retryAttempt == 10)
        #expect(session.nextRetryDelay == 0.1)

        session.resetRetryAttempts()

        #expect(session.nextRetryDelay == 0.04)
    }
}
