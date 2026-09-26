import Testing
@testable import MyIMECore

struct SingleLetterDictionaryCandidateFilterTests {
    @Test func removesSymbolShorthandsFromSingleLetterInput() {
        #expect(SingleLetterDictionaryCandidateFilter.candidates(
            ["亜", "あ", "ア", "A", "Å", "β", "→"],
            for: "a"
        ) == ["亜", "あ", "ア", "A"])
    }

    @Test func preservesNamedAndMultiLetterInput() {
        let candidates = ["β", "ベータ"]
        #expect(SingleLetterDictionaryCandidateFilter.candidates(
            candidates,
            for: "be-ta"
        ) == candidates)
    }

    @Test func preservesWordsFromSingleLetterInput() {
        let candidates = ["ビー", "beta"]
        #expect(SingleLetterDictionaryCandidateFilter.candidates(
            candidates,
            for: "b"
        ) == candidates)
    }
}
