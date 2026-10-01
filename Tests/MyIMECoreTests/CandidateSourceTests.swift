import Testing
@testable import MyIMECore

@Suite
struct CandidateSourceTests {
    private struct StubSource: CandidateSource {
        let kind: CandidateSourceKind
        let values: [String]
        let delay: Duration

        func candidates(
            for context: CandidateSourceContext
        ) async -> [Candidate] {
            try? await Task.sleep(for: delay)
            return values.map {
                Candidate(
                    storageText: $0,
                    source: kind,
                    reading: context.conversionReading,
                    isLearnable: kind == .wikipedia
                )
            }
        }
    }

    @Test
    func preservesSourceOrderWhenAsyncSourcesFinishOutOfOrder() async {
        let context = CandidateSourceContext(
            input: "kouho",
            conversionReading: "kouho",
            japaneseReading: "こうほ"
        )
        let candidates = await CandidateSourceCollector.candidates(
            from: [
                StubSource(
                    kind: .wikipedia,
                    values: ["候補", "候補者"],
                    delay: .milliseconds(10)
                ),
                StubSource(
                    kind: .googleJapaneseInput,
                    values: ["候補", "公募"],
                    delay: .zero
                )
            ],
            context: context
        )

        #expect(candidates.map(\.storageText) == ["候補", "候補者", "公募"])
        #expect(candidates[0].sources == [.wikipedia, .googleJapaneseInput])
        #expect(candidates[0].isLearnable)
    }
}
