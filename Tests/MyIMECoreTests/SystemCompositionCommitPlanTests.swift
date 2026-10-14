import Testing
@testable import MyIMECore

@Suite
struct SystemCompositionCommitPlanTests {
    @Test
    func commitsAndLearnsTheActuallySelectedCandidate() throws {
        let storageText = try #require(
            DictionaryCandidateRepresentation.encoded(
                display: "Google",
                value: "https://www.google.com/"
            )
        )
        let candidate = Candidate(
            storageText: storageText,
            source: .userDictionary,
            reading: "google"
        )

        let plan = SystemCompositionCommitPlan.resolve(
            originalInput: "google",
            selectedCandidate: candidate,
            conversionSuffix: "!",
            compositionSuffix: "?"
        )

        #expect(plan.committedText == "https://www.google.com/!?")
        #expect(plan.selectedCandidate == candidate)
        #expect(plan.unselectedInputLearningEntry == nil)
    }

    @Test
    func unselectedCommitKeepsTheExistingRawInputLearning() throws {
        let plan = SystemCompositionCommitPlan.resolve(
            originalInput: "E06S",
            selectedCandidate: nil
        )

        #expect(plan.committedText == "E06S")
        #expect(plan.selectedCandidate == nil)
        let entry = try #require(plan.unselectedInputLearningEntry)
        #expect(entry.reading == "e06s")
        #expect(entry.candidate == "E06S")
    }

    @Test
    func unselectedSingleEnglishLetterIsNotLearned() {
        let plan = SystemCompositionCommitPlan.resolve(
            originalInput: "a",
            selectedCandidate: nil
        )

        #expect(plan.committedText == "a")
        #expect(plan.unselectedInputLearningEntry == nil)
    }
}
