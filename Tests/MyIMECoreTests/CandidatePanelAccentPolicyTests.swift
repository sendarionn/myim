import Testing
@testable import MyIMECore

@Suite
struct CandidatePanelAccentPolicyTests {
    @Test
    func accentsDictionaryRegistrationCandidates() {
        #expect(CandidatePanelAccentPolicy.isAccented(
            isDictionaryRegistration: true
        ))
    }

    @Test
    func leavesOrdinaryCandidatesUnaccented() {
        #expect(!CandidatePanelAccentPolicy.isAccented(
            isDictionaryRegistration: false
        ))
    }
}
