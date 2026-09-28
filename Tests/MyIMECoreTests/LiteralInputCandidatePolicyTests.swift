import Testing
@testable import MyIMECore

@Suite
struct LiteralInputCandidatePolicyTests {
    @Test
    func exposesOriginalInputWhenItIsMissingFromExactCandidates() {
        #expect(
            LiteralInputCandidatePolicy.candidate(
                input: "Wi-Fi",
                exactDictionaryCandidates: ["ワイファイ"]
            ) == "Wi-Fi"
        )
    }

    @Test
    func doesNotDuplicateOriginalInputAlreadyInExactCandidates() {
        #expect(
            LiteralInputCandidatePolicy.candidate(
                input: "Wi-Fi",
                exactDictionaryCandidates: ["Wi-Fi", "ワイファイ"]
            ) == nil
        )
    }

    @Test
    func recognizesOriginalInputStoredWithASeparateDisplayName() throws {
        let stored = try #require(DictionaryCandidateRepresentation.encoded(
            display: "無線LAN",
            value: "Wi-Fi"
        ))

        #expect(
            LiteralInputCandidatePolicy.candidate(
                input: "Wi-Fi",
                exactDictionaryCandidates: [stored]
            ) == nil
        )
    }

    @Test
    func selectedLiteralCanBeStoredAndFoundByItsPrefix() {
        let entries = UserDictionaryEditor.adding(
            reading: "Wi-Fi",
            candidate: "Wi-Fi",
            to: []
        )
        let groups = ConversionEngine(entries: entries).candidateGroups(
            matching: "wi-"
        )

        #expect(groups.exact.isEmpty)
        #expect(groups.prefix == ["Wi-Fi"])
    }

    @Test
    func learnedCandidateSurvivesHyphenFilterForLowercasePrefix() {
        let entries = UserDictionaryEditor.adding(
            reading: "Wi-Fi",
            candidate: "Wi-Fi",
            to: []
        )
        let prefixCandidates = ConversionEngine(entries: entries)
            .candidateGroups(matching: "wi-").prefix

        #expect(
            LongVowelNotationCandidateFilter.candidates(
                prefixCandidates,
                for: "wi-",
                preserving: Set(prefixCandidates)
            ) == ["Wi-Fi"]
        )
    }
}
