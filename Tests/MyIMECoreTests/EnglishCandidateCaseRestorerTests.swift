import Testing
@testable import MyIMECore

@Suite
struct EnglishCandidateCaseRestorerTests {
    @Test
    func createsAllUppercaseCandidate() {
        #expect(
            EnglishCandidateCaseRestorer.uppercaseCandidate(for: "myim")
                == "MYIM"
        )
        #expect(
            EnglishCandidateCaseRestorer.uppercaseCandidate(for: "OpenAI")
                == "OPENAI"
        )
        #expect(
            EnglishCandidateCaseRestorer.uppercaseCandidate(for: "MYIM")
                == nil
        )
        #expect(
            EnglishCandidateCaseRestorer.uppercaseCandidate(for: "myim2")
                == nil
        )
    }

    @Test
    func preservesTypedUppercaseLetters() {
        #expect(
            EnglishCandidateCaseRestorer.restore(
                typedInput: "Ret",
                in: "return"
            ) == "Return"
        )
        #expect(
            EnglishCandidateCaseRestorer.restore(
                typedInput: "RET",
                in: "return"
            ) == "RETurn"
        )
    }

    @Test
    func leavesUnrelatedCandidatesUnchanged() {
        #expect(
            EnglishCandidateCaseRestorer.restore(
                typedInput: "Ret",
                in: "result"
            ) == "result"
        )
    }
}
