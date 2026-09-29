import Testing
@testable import MyIMECore

@Suite struct CandidateLocationRetryPolicyTests {
    @Test func retriesQuicklyWhileTheClientLayoutSettles() {
        #expect(CandidateLocationRetryPolicy.delay(after: 0) == 0.04)
        #expect(CandidateLocationRetryPolicy.delay(after: 9) == 0.04)
    }

    @Test func backsOffWithoutStoppingTheActiveInputSession() {
        #expect(CandidateLocationRetryPolicy.delay(after: 10) == 0.1)
        #expect(CandidateLocationRetryPolicy.delay(after: 29) == 0.1)
        #expect(CandidateLocationRetryPolicy.delay(after: 30) == 0.25)
        #expect(CandidateLocationRetryPolicy.delay(after: 100) == 0.25)
    }
}
