import Testing
@testable import MyIMECore

@Suite
struct StandardConversionCandidateSourceTests {
    @Test
    func gathersDictionaryCandidatesWithTheirSources() {
        let source = makeSource(
            userEntries: [DictionaryEntry(reading: "kouho", candidates: ["候補"])],
            basicEntries: [DictionaryEntry(reading: "kouho", candidates: ["公募"])]
        )

        let candidates = source.candidates(for: .init(
            input: "kouho",
            conversionReading: "kouho"
        ))

        #expect(candidates.first?.storageText == "候補")
        #expect(candidates.first?.hasSource(.userDictionary) == true)
        #expect(candidates.contains {
            $0.storageText == "公募" && $0.hasSource(.basicDictionary)
        })
    }

    @Test
    func generatesNumericPrefixCandidatesInsideTheSource() {
        let source = makeSource(
            basicEntries: [DictionaryEntry(reading: "nin", candidates: ["人"])]
        )

        let candidates = source.candidates(for: .init(
            input: "1nin",
            conversionReading: "1nin"
        ))

        #expect(candidates.contains { $0.storageText == "1人" })
    }

    @Test
    func marksGeneratedParticleCandidatesAsLearnable() throws {
        let source = makeSource(
            basicEntries: [DictionaryEntry(
                reading: "kouho",
                candidates: ["候補"]
            )]
        )

        let candidate = try #require(source.candidates(for: .init(
            input: "kouhowo",
            conversionReading: "kouhowo"
        )).first { $0.storageText == "候補を" })

        #expect(candidate.hasSource(.particleComposition))
        #expect(candidate.hasAttribute(.generated))
        #expect(candidate.isLearnable)
    }

    @Test
    func keepsExternalAndEnglishCandidatesInThePipeline() {
        let source = makeSource()
        let candidates = source.candidates(for: .init(
            input: "code",
            conversionReading: "code",
            externalCandidates: [Candidate(
                storageText: "外部候補",
                source: .wikipedia
            )],
            englishCandidates: ["coder"]
        ))

        #expect(candidates.contains { $0.storageText == "外部候補" })
        #expect(candidates.contains { $0.storageText == "coder" })
        #expect(candidates.suffix(2).map(\.storageText) == ["Code", "CODE"])
    }

    private func makeSource(
        userEntries: [DictionaryEntry] = [],
        basicEntries: [DictionaryEntry] = []
    ) -> StandardConversionCandidateSource {
        StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: [
                ConversionEngine(entries: userEntries)
            ]),
            basicEngine: ConversionEngine(entries: basicEntries),
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: IndexedDictionaryEngine(),
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: basicEntries
            )
        )
    }
}
