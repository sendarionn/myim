import Testing
@testable import MyIMECore

@Suite
struct CandidateDeletionCommandPolicyTests {
    @Test
    func routesAStandardCandidateSelection() {
        #expect(CandidateDeletionCommandPolicy.target(
            hasInput: true,
            hasStandardSelection: true,
            hasFuzzySelection: false,
            hasNextInputSelection: false
        ) == .standardCandidate)
    }

    @Test
    func routesAFuzzySelectionBeforeTheStandardSelection() {
        #expect(CandidateDeletionCommandPolicy.target(
            hasInput: true,
            hasStandardSelection: true,
            hasFuzzySelection: true,
            hasNextInputSelection: false
        ) == .fuzzyCandidate)
    }

    @Test
    func routesANextInputSelectionOnlyWithoutComposition() {
        #expect(CandidateDeletionCommandPolicy.target(
            hasInput: false,
            hasStandardSelection: false,
            hasFuzzySelection: false,
            hasNextInputSelection: true
        ) == .nextInputCandidate)
        #expect(CandidateDeletionCommandPolicy.target(
            hasInput: true,
            hasStandardSelection: false,
            hasFuzzySelection: false,
            hasNextInputSelection: true
        ) == nil)
    }

    @Test
    func doesNotCaptureWithoutASelectedCandidate() {
        #expect(CandidateDeletionCommandPolicy.target(
            hasInput: true,
            hasStandardSelection: false,
            hasFuzzySelection: false,
            hasNextInputSelection: false
        ) == nil)
    }
}
