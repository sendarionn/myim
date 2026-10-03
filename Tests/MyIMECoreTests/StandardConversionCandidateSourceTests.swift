import Foundation
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

    @Test
    func particleStemsIgnoreImportedAbbrevHeadwords() {
        let source = makeSource(
            importedEntries: [DictionaryEntry(reading: "made", candidates: ["メイド"])],
            basicEntries: [DictionaryEntry(reading: "made", candidates: ["まで"])]
        )

        let particle = source.candidates(for: .init(
            input: "madeha",
            conversionReading: "madeha"
        )).map(\.storageText)
        let direct = source.candidates(for: .init(
            input: "made",
            conversionReading: "made"
        )).map(\.storageText)

        #expect(particle.first == "までは")
        #expect(!particle.contains("メイドは"))
        #expect(direct.contains("メイド"))
    }

    @Test
    func particleStemsStillUseTheUsersOwnDictionary() {
        let source = makeSource(
            userEntries: [DictionaryEntry(reading: "myim", candidates: ["マイム"])]
        )

        let candidates = source.candidates(for: .init(
            input: "myimwo",
            conversionReading: "myimwo"
        )).map(\.storageText)

        #expect(candidates.first == "マイムを")
    }

    @Test
    func wholeInputExactCandidateOutranksAGeneratedParticleComposition() {
        let source = makeSource(basicEntries: [
            DictionaryEntry(reading: "kouho", candidates: ["候補"]),
            DictionaryEntry(reading: "kouhowo", candidates: ["好捕を"])
        ])

        let candidates = source.candidates(for: .init(
            input: "kouhowo",
            conversionReading: "kouhowo"
        ))

        #expect(candidates.map(\.storageText).prefix(2) == ["好捕を", "候補を"])
        #expect(candidates[1].hasSource(.particleComposition))
        #expect(candidates[1].hasAttribute(.generated))
    }

    @Test
    func basicDictionaryAloneRanksTheReadingFirst() {
        let candidates = texts(makeSource(basicEntries: madeBasic), "made")

        #expect(candidates.first == "まで")
    }

    @Test
    func importedReadingMatchesFollowBuiltInDictionaries() {
        let source = makeSource(
            importedEntries: madeImported,
            basicEntries: madeBasic
        )

        let candidates = source.candidates(for: .init(
            input: "made",
            conversionReading: "made"
        ))
        let values = candidates.map(\.storageText)

        #expect(values.prefix(2) == ["まで", "迄"])
        #expect(candidates[1].hasSource(.importedDictionary))
        #expect(!candidates[1].hasSource(.userDictionary))
    }

    @Test
    func importedSpellingMatchesFollowReadingMatchesAndKana() throws {
        let values = texts(
            makeSource(importedEntries: madeImported, basicEntries: madeBasic),
            "made"
        )

        let maid = try #require(values.firstIndex(of: "メイド"))
        let katakana = try #require(values.firstIndex(of: "マデ"))
        #expect(maid > katakana)
        #expect(values.firstIndex(of: "メード") == maid + 1)
    }

    @Test
    func importedDictionaryAloneStillPrefersItsReadingMatch() {
        let values = texts(makeSource(importedEntries: madeImported), "made")

        #expect(values.first == "迄")
        #expect(values.contains("メイド"))
    }

    @Test
    func importedSpellingMatchesLeadWhenNothingMatchesTheReading() {
        let values = texts(
            makeSource(importedEntries: [
                DictionaryEntry(reading: "computer", candidates: ["コンピュータ"])
            ]),
            "computer"
        )

        #expect(values.first == "コンピュータ")
    }

    @Test
    func explicitUserRegistrationKeepsItsPriority() {
        let values = texts(
            makeSource(
                userEntries: [DictionaryEntry(reading: "made", candidates: ["メイド"])],
                importedEntries: madeImported,
                basicEntries: madeBasic
            ),
            "made"
        )

        #expect(values.prefix(3) == ["メイド", "まで", "迄"])
    }

    @Test
    func exactMatchesFromEachDictionaryKeepTheirDictionaryOrder() {
        let values = texts(
            makeSource(
                userEntries: [DictionaryEntry(reading: "kouho", candidates: ["校補"])],
                importedEntries: [
                    DictionaryEntry(reading: "こうほ", candidates: ["好捕", "候補"])
                ],
                basicEntries: [DictionaryEntry(reading: "kouho", candidates: ["候補"])]
            ),
            "kouho"
        )

        #expect(values.prefix(3) == ["校補", "候補", "好捕"])
    }

    @Test
    func deferredSystemCandidatesFollowParticleCompositions() {
        let values = texts(
            makeSource(
                basicEntries: [DictionaryEntry(reading: "tsugi", candidates: ["次"])],
                systemText: "tsugino\t調\n",
                deferred: "tsugino\t調\n"
            ),
            "tugino"
        )

        #expect(values.prefix(2) == ["次の", "調"])
    }

    @Test
    func undeferredSystemCandidatesKeepTheirExactMatchPriority() {
        let values = texts(
            makeSource(
                basicEntries: [DictionaryEntry(reading: "tsugi", candidates: ["次"])],
                systemText: "tsugino\t調\n"
            ),
            "tugino"
        )

        #expect(values.prefix(2) == ["調", "次の"])
    }

    @Test
    func deferredSystemCandidatesStayAheadOfAutomaticKana() throws {
        let values = texts(
            makeSource(
                systemText: "tanaka\t田仲\n",
                deferred: "tanaka\t田仲\n"
            ),
            "tanaka"
        )

        let name = try #require(values.firstIndex(of: "田仲"))
        let kana = try #require(values.firstIndex(of: "たなか"))
        #expect(name < kana)
    }

    private let madeBasic = [DictionaryEntry(reading: "made", candidates: ["まで"])]
    private let madeImported = [
        DictionaryEntry(reading: "made", candidates: ["メイド", "メード"]),
        DictionaryEntry(reading: "まで", candidates: ["迄"])
    ]

    private func texts(
        _ source: StandardConversionCandidateSource,
        _ input: String
    ) -> [String] {
        source.candidates(for: .init(
            input: input,
            conversionReading: input
        )).map(\.storageText)
    }

    private func makeSource(
        userEntries: [DictionaryEntry] = [],
        importedEntries: [DictionaryEntry] = [],
        basicEntries: [DictionaryEntry] = [],
        systemText: String = "",
        deferred: String = ""
    ) -> StandardConversionCandidateSource {
        StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: [
                ConversionEngine(entries: userEntries)
            ]),
            importedEngine: LayeredConversionEngine(engines: [
                ConversionEngine(entries: importedEntries)
            ]),
            basicEngine: ConversionEngine(entries: basicEntries),
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: IndexedDictionaryEngine(data: Data(systemText.utf8)),
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: basicEntries
            ),
            deferredSystemCandidates: DeferredSystemCandidates(text: deferred)
        )
    }
}
