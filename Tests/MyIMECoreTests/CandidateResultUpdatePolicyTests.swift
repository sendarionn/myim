import Testing
@testable import MyIMECore

struct CandidateResultUpdatePolicyTests {
    @Test
    func unchangedEmptyResultDoesNotRequireCandidateRefresh() {
        #expect(!CandidateResultUpdatePolicy.changes(
            current: [String](),
            updated: []
        ))
    }

    @Test
    func changedResultRequiresCandidateRefresh() {
        #expect(CandidateResultUpdatePolicy.changes(
            current: [String](),
            updated: ["候補"]
        ))
    }
}
