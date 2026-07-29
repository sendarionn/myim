import Testing
@testable import MyIMECore

@Suite
struct JapaneseVerbInflectorTests {
    @Test
    func createsSokuonbinTeForms() {
        let dictionary = [
            "utsu": ["打つ"],
            "utsuru": ["移る"]
        ]

        #expect(
            JapaneseVerbInflector.teFormCandidates(
                for: "utsutte",
                lookup: { dictionary[$0] ?? [] }
            ) == ["打って", "移って"]
        )
    }
}
