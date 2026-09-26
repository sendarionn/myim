import Testing
@testable import MyIMECore

@Suite
struct CandidatePanelAccentPolicyTests {
    @Test
    func accentsDictionaryRegistrationCandidates() {
        #expect(CandidatePanelAccentPolicy.isAccented(
            isTranslationInput: false,
            isDictionaryRegistration: true
        ))
    }

    @Test
    func leavesOrdinaryCandidatesUnaccented() {
        #expect(!CandidatePanelAccentPolicy.isAccented(
            isTranslationInput: false,
            isDictionaryRegistration: false
        ))
    }
}
