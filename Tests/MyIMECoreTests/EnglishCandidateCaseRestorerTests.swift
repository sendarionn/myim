import Testing
@testable import MyIMECore

@Suite
struct EnglishCandidateCaseRestorerTests {
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
