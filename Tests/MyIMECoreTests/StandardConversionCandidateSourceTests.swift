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
    func keepsLearnedLongVowelCandidateDuringPrefixCompletion() throws {
        let source = makeSource()
        var history = CandidateSelectionHistory()
        history.record("ホットペッパー", reading: "hottopeppa-")
        let saved = try JSONEncoder().encode(history)
        let restored = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: saved
        )

        for input in ["hottope", "hottopep", "hottopepp"] {
            let generated = source.candidates(for: .init(
                input: input,
                conversionReading: input,
                selectionHistory: restored
            ))
            let learned = try #require(generated.first {
                $0.storageText == "ホットペッパー"
            })
            #expect(learned.hasSource(.selectionHistory))

            var session = CandidateSession()
            session.replace(with: generated, input: input, reading: input)
            #expect(
                session.candidateTexts.prefix(4).contains("ホットペッパー")
            )
        }
    }

    @Test
    func keepsLearnedCompletionFromOneCharacterInStandardCandidates() throws {
        let source = makeSource()
        var history = CandidateSelectionHistory()
        history.record("Smartlock", reading: "smartlock")

        let learned = try #require(source.candidates(for: .init(
            input: "s",
            conversionReading: "s",
            selectionHistory: history
        )).first { $0.storageText == "Smartlock" })

        #expect(learned.hasSource(.selectionHistory))
    }

    @Test(arguments: ["smar", "Smar", "SMAR", "sMaR"])
    func learnedCompletionLookupIgnoresReadingCase(input: String) throws {
        let source = makeSource()
        var history = CandidateSelectionHistory()
        history.record("Smart Inn", reading: "SmArTiNn")

        let learned = try #require(source.candidates(for: .init(
            input: input,
            conversionReading: input,
            selectionHistory: history
        )).first { $0.storageText == "Smart Inn" })

        #expect(learned.storageText == "Smart Inn")
        #expect(learned.hasSource(.selectionHistory))
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
    func wholeInputExactCandidateOutranksALeadingParticleComposition() throws {
        let source = makeSource(basicEntries: [
            DictionaryEntry(reading: "baai", candidates: ["場合"]),
            DictionaryEntry(reading: "nobaai", candidates: ["野場合"])
        ])

        let candidates = source.candidates(for: .init(
            input: "nobaai",
            conversionReading: "nobaai"
        ))
        let composition = try #require(candidates.first {
            $0.storageText == "の場合"
        })

        #expect(candidates.first?.storageText == "野場合")
        #expect(composition.hasSource(.particleComposition))
        #expect(composition.hasAttribute(.generated))
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

    @Test
    func directLongVowelLookupDoesNotFetchUnrelatedSystemCandidate() {
        let source = makeSource(systemText: """
        beppu\t別府
        byu-\tビュー
        byuu\t別府
        """)

        let generated = source.candidates(for: .init(
            input: "byu-",
            conversionReading: "byu-"
        ))
        let visible = visibleCandidates(
            generated,
            input: "byu-",
            reading: "byu-"
        )

        #expect(!generated.contains { $0.storageText == "別府" })
        #expect(visible.contains("ビュー"))
        #expect(!visible.contains("別府"))
        #expect(texts(source, "beppu").contains("別府"))
    }

    @Test
    func directHyphenDictionaryMatchesRemainVisible() {
        let source = makeSource(
            userEntries: [DictionaryEntry(
                reading: "wi-fi",
                candidates: ["Wi-Fi"]
            )],
            symbolEntries: [DictionaryEntry(
                reading: "nyu-",
                candidates: ["ν"]
            )]
        )

        let symbol = visibleCandidates(
            source.candidates(for: .init(
                input: "nyu-",
                conversionReading: "nyu-"
            )),
            input: "nyu-",
            reading: "nyu-"
        )
        let user = visibleCandidates(
            source.candidates(for: .init(
                input: "Wi-Fi",
                conversionReading: "Wi-Fi"
            )),
            input: "Wi-Fi",
            reading: "Wi-Fi"
        )

        #expect(symbol.contains("ν"))
        #expect(user.contains("Wi-Fi"))
    }

    @Test(arguments: [
        ("cc", "テストCC"),
        ("rlj", "テストRLJ"),
        ("zz", "テストZZ"),
        ("abc", "テストABC"),
        ("byu-", "テストBYU")
    ])
    func arbitraryUserDictionaryReadingsReachTheVisibleCandidates(
        reading: String,
        expected: String
    ) {
        let source = makeSource(userEntries: [DictionaryEntry(
            reading: reading,
            candidates: [expected]
        )])
        let visible = visibleCandidates(
            source.candidates(for: .init(
                input: reading,
                conversionReading: ConversionReadingResolver.resolve(reading)
            )),
            input: reading,
            reading: ConversionReadingResolver.resolve(reading)
        )

        #expect(visible.contains(expected))
    }

    @Test(arguments: [
        ("cc", "セールスCC"),
        ("rlj", "リモートロックジャパン")
    ])
    func exactUserDictionaryCandidateMayUseLongVowelNotation(
        reading: String,
        expected: String
    ) {
        let source = makeSource(userEntries: [DictionaryEntry(
            reading: reading,
            candidates: [expected]
        )])
        let visible = visibleCandidates(
            source.candidates(for: .init(
                input: reading,
                conversionReading: reading
            )),
            input: reading,
            reading: reading
        )

        #expect(visible.contains(expected))
    }

    @Test
    func legacyUserLongVowelKeyRemainsSearchable() {
        let source = makeSource(userEntries: [DictionaryEntry(
            reading: "yuuzaa",
            candidates: ["ユーザー"]
        )])

        #expect(texts(source, "yu-za-").contains("ユーザー"))
        #expect(texts(source, "yu-za-no").contains("ユーザーの"))
    }

    @Test
    func basicDictionaryInflectionRequiresMozcVerbRegistration() {
        let source = makeSource(
            basicEntries: [DictionaryEntry(
                reading: "neru",
                candidates: ["寝る"]
            )]
        )

        #expect(texts(source, "neru").contains("寝る"))
        #expect(!texts(source, "netai").contains("寝たい"))
        #expect(!texts(source, "nerareru").contains("寝られる"))
    }

    @Test
    func systemDictionaryInflectionRequiresMozcVerbRegistration() {
        let source = makeSource(systemText: "neru\t寝る\n")

        #expect(texts(source, "neru").contains("寝る"))
        #expect(!texts(source, "netai").contains("寝たい"))
        #expect(!texts(source, "nerareru").contains("寝られる"))
    }

    @Test
    func registeredVerbStillInflectsFromBothDictionaryLayers() {
        let verbText = "kaku\t書く\tgodan\t3000\n"

        #expect(texts(makeSource(
            basicEntries: [DictionaryEntry(
                reading: "kaku",
                candidates: ["書く"]
            )],
            verbText: verbText
        ), "kaite").contains("書いて"))
        #expect(texts(makeSource(
            systemText: "kaku\t書く\n",
            verbText: verbText
        ), "kaite").contains("書いて"))
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

    private func visibleCandidates(
        _ candidates: [Candidate],
        input: String,
        reading: String
    ) -> [String] {
        var session = CandidateSession()
        session.replace(with: candidates, input: input, reading: reading)
        return session.candidateTexts
    }

    private func makeSource(
        userEntries: [DictionaryEntry] = [],
        importedEntries: [DictionaryEntry] = [],
        basicEntries: [DictionaryEntry] = [],
        symbolEntries: [DictionaryEntry] = [],
        systemText: String = "",
        deferred: String = "",
        verbText: String = ""
    ) -> StandardConversionCandidateSource {
        StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: [
                ConversionEngine(entries: userEntries)
            ]),
            importedEngine: LayeredConversionEngine(engines: [
                ConversionEngine(entries: importedEntries)
            ]),
            basicEngine: ConversionEngine(entries: basicEntries),
            symbolEngine: ConversionEngine(entries: symbolEntries),
            systemEngine: IndexedDictionaryEngine(data: Data(systemText.utf8)),
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: basicEntries
            ),
            deferredSystemCandidates: DeferredSystemCandidates(text: deferred),
            verbConjugations: VerbConjugationDictionary(text: verbText)
        )
    }
}
