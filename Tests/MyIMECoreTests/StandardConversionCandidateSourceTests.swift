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
    func singleHiraganaRemainsFirstThroughStandardCandidateGeneration() {
        let source = makeSource(
            userEntries: [DictionaryEntry(reading: "ki", candidates: ["木"])],
            basicEntries: [DictionaryEntry(reading: "ki", candidates: ["気"])]
        )
        var history = CandidateSelectionHistory()
        history.record("機会", reading: "ki")
        history.record("機会", reading: "ki")

        let candidates = source.candidates(for: .init(
            input: "ki",
            conversionReading: "ki",
            selectionHistory: history,
            contextualCandidates: ["気"]
        ))

        #expect(candidates.first?.storageText == "き")
        #expect(candidates.contains { $0.storageText == "キ" })
        #expect(candidates.contains { $0.storageText == "木" })
        #expect(candidates.contains { $0.storageText == "気" })
        #expect(candidates.contains { $0.storageText == "機会" })
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
    func keepsEnglishCandidatesInThePipeline() {
        let source = makeSource()
        let candidates = source.candidates(for: .init(
            input: "code",
            conversionReading: "code",
            englishCandidates: ["coder"]
        ))

        #expect(candidates.contains { $0.storageText == "coder" })
        #expect(candidates.suffix(2).map(\.storageText) == ["Code", "CODE"])
    }

    @Test
    func keepsDirectTimeFormatsInStandardCandidates() {
        let candidates = makeSource().candidates(for: .init(
            input: "14:30",
            conversionReading: "",
            javaScriptCandidates: [
                .init(value: "14時30分"),
                .init(value: "14時半")
            ]
        )).map(\.storageText)

        #expect(candidates.prefix(2) == ["14時30分", "14時半"])
        #expect(!candidates.contains("14:30"))
    }

    @Test
    func marksDynamicDateTimeCandidatesWithoutChangingStaticDuplicates() throws {
        let dynamicOnly = try #require(makeSource().candidates(for: .init(
            input: "kyou",
            conversionReading: "kyou",
            javaScriptCandidates: [
                .init(
                    value: "20261031",
                    kind: .dynamicDateTime,
                    preferenceID: "dynamic_date:kyou:YYYYMMDD"
                )
            ]
        )).first { $0.storageText == "20261031" })
        #expect(dynamicOnly.hasSource(.dateTime))
        #expect(!dynamicOnly.allowsSelectionHistory)
        #expect(
            dynamicOnly.dynamicPreferenceID
                == "dynamic_date:kyou:YYYYMMDD"
        )

        let scriptDuplicate = try #require(makeSource().candidates(for: .init(
            input: "kyou",
            conversionReading: "kyou",
            javaScriptCandidates: [
                .init(value: "20261031", kind: .dynamicDateTime),
                .init(value: "20261031")
            ]
        )).first { $0.storageText == "20261031" })
        #expect(scriptDuplicate.sources.contains(.dateTime))
        #expect(scriptDuplicate.sources.contains(.javaScriptExtension))
        #expect(scriptDuplicate.allowsSelectionHistory)

        let merged = try #require(makeSource(
            userEntries: [DictionaryEntry(
                reading: "kyou",
                candidates: ["20261031"]
            )]
        ).candidates(for: .init(
            input: "kyou",
            conversionReading: "kyou",
            javaScriptCandidates: [
                .init(value: "20261031", kind: .dynamicDateTime)
            ]
        )).first { $0.storageText == "20261031" })
        #expect(merged.sources.contains(.dateTime))
        #expect(merged.sources.contains(.userDictionary))
        #expect(merged.allowsSelectionHistory)
    }

    @Test
    func keepsLearnedDynamicFormatFirstAfterTheDateChanges() throws {
        var history = CandidateSelectionHistory()
        history.record(
            "dynamic_date:kyou:M/D(E)",
            readings: []
        )
        let restored = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: JSONEncoder().encode(history)
        )

        let candidates = makeSource().candidates(for: .init(
            input: "kyou",
            conversionReading: "kyou",
            javaScriptCandidates: [
                .init(
                    value: "20261101",
                    kind: .dynamicDateTime,
                    preferenceID: "dynamic_date:kyou:YYYYMMDD"
                ),
                .init(
                    value: "11/1(日)",
                    kind: .dynamicDateTime,
                    preferenceID: "dynamic_date:kyou:M/D(E)"
                )
            ],
            selectionHistory: restored
        ))

        #expect(candidates.first?.storageText == "11/1(日)")
        #expect(!candidates.contains { $0.storageText == "10/31(土)" })
    }

    @Test
    func ordersNormalAndDynamicCandidatesByTheirSharedLastUse() throws {
        var history = CandidateSelectionHistory()
        history.record("今日", reading: "kyou")
        history.record("今日", reading: "kyou")
        history.record(
            "dynamic_date:kyou:YYYYMMDD",
            readings: []
        )
        history = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: JSONEncoder().encode(history)
        )

        let source = makeSource(
            basicEntries: [DictionaryEntry(
                reading: "kyou",
                candidates: ["今日"]
            )]
        )
        let javaScriptCandidates = [
            JavaScriptExtensionCandidate(
                value: "20261101",
                kind: .dynamicDateTime,
                preferenceID: "dynamic_date:kyou:YYYYMMDD"
            )
        ]
        func candidates() -> [String] {
            source.candidates(for: .init(
                input: "kyou",
                conversionReading: "kyou",
                javaScriptCandidates: javaScriptCandidates,
                selectionHistory: history
            )).map(\.storageText)
        }

        #expect(candidates().prefix(2) == ["20261101", "今日"])

        history.record("今日", reading: "kyou")
        history = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: JSONEncoder().encode(history)
        )

        #expect(candidates().prefix(2) == ["今日", "20261101"])
    }

    /// A time learned or registered as typed is not offered again, since
    /// committing without a candidate already gives it
    @Test(arguments: ["13:00", "0930"])
    func hidesTheTypedTimeItself(input: String) {
        let candidates = makeSource(
            userEntries: [DictionaryEntry(reading: input, candidates: [input])]
        ).candidates(for: .init(
            input: input,
            conversionReading: ConversionReadingResolver.resolve(input),
            javaScriptCandidates: [.init(value: "13時0分")]
        )).map(\.storageText)

        #expect(candidates == ["13時0分"])
    }

    @Test
    func keepsLearnedLongVowelCandidateDuringPrefixCompletion() throws {
        let source = makeSource()
        var history = CandidateSelectionHistory()
        history.record("ホットペッパー", reading: "hottopeppa-")
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
    func learnedParticleCompositionOutranksWholeInputExactCandidate() throws {
        let source = makeSource(basicEntries: [
            DictionaryEntry(reading: "kouho", candidates: ["候補"]),
            DictionaryEntry(reading: "kouhowo", candidates: ["好捕を"])
        ])
        var history = CandidateSelectionHistory()
        for _ in 0..<3 {
            history.record("候補を", reading: "kouhowo")
        }
        history = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: JSONEncoder().encode(history)
        )

        let candidates = source.candidates(for: .init(
            input: "kouhowo",
            conversionReading: "kouhowo",
            selectionHistory: history
        ))

        #expect(candidates.map(\.storageText).prefix(2) == ["候補を", "好捕を"])
        #expect(candidates[0].hasSource(.particleComposition))
        #expect(candidates[0].hasAttribute(.generated))
    }

    @Test
    func exactDuplicateKeepsItsDictionaryOriginAheadOfComposition() throws {
        let source = makeSource(basicEntries: [
            DictionaryEntry(reading: "kouho", candidates: ["候補"]),
            DictionaryEntry(reading: "kouhowo", candidates: ["候補を"])
        ])

        let candidate = try #require(source.candidates(for: .init(
            input: "kouhowo",
            conversionReading: "kouhowo"
        )).first { $0.storageText == "候補を" })

        #expect(candidate.primarySource == .basicDictionary)
        #expect(candidate.hasSource(.basicDictionary))
        #expect(candidate.hasSource(.particleComposition))
    }

    @Test
    func learnedNumericPrefixCompositionOutranksWholeInputExactCandidate() throws {
        let source = makeSource(basicEntries: [
            DictionaryEntry(reading: "nin", candidates: ["人"]),
            DictionaryEntry(reading: "1nin", candidates: ["一任"])
        ])
        var history = CandidateSelectionHistory()
        history.record("1人", reading: "1nin")

        let values = source.candidates(for: .init(
            input: "1nin",
            conversionReading: "1nin",
            selectionHistory: history
        )).map(\.storageText)

        let exactIndex = try #require(values.firstIndex(of: "一任"))
        let compositionIndex = try #require(values.firstIndex(of: "1人"))

        #expect(compositionIndex < exactIndex)
    }

    @Test
    func learnedCompoundVerbInflectionOutranksWholeInputExactCandidate() throws {
        let source = makeSource(
            basicEntries: [DictionaryEntry(
                reading: "yobaretemo",
                candidates: ["呼ばれても完全一致"]
            )],
            verbText: "yobu\t呼ぶ\tgodan\t2756\n"
        )
        var history = CandidateSelectionHistory()
        history.record("呼ばれても", reading: "yobaretemo")

        let values = source.candidates(for: .init(
            input: "yobaretemo",
            conversionReading: "yobaretemo",
            selectionHistory: history
        )).map(\.storageText)

        let exactIndex = try #require(
            values.firstIndex(of: "呼ばれても完全一致")
        )
        let compositionIndex = try #require(
            values.firstIndex(of: "呼ばれても")
        )

        #expect(compositionIndex < exactIndex)
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
    func importedSpellingExactMatchesFollowReadingExactMatches() throws {
        let values = texts(
            makeSource(importedEntries: madeImported, basicEntries: madeBasic),
            "made"
        )

        let maid = try #require(values.firstIndex(of: "メイド"))
        let readingMatch = try #require(values.firstIndex(of: "迄"))
        let katakana = try #require(values.firstIndex(of: "マデ"))
        #expect(readingMatch < maid)
        #expect(maid < katakana)
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
    func exactSystemCandidatesDoNotFollowParticleCompositions() {
        let values = texts(
            makeSource(
                basicEntries: [DictionaryEntry(reading: "tsugi", candidates: ["次"])],
                systemText: "tsugino\t調\n",
                deferred: "tsugino\t調\n"
            ),
            "tugino"
        )

        #expect(values.prefix(2) == ["調", "次の"])
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

    @Test(arguments: [
        ("arimasu", "アリマス", "あります", "aru\tある\tgodan\t0\n"),
        ("shite", "シテ", "して", "suru\tする\tsuru\t0\n")
    ])
    func repeatedSelectionPromotesAutomaticKanaWithoutReclassifyingIt(
        input: String,
        exact: String,
        generated: String,
        verbText: String
    ) throws {
        let source = makeSource(
            systemText: "\(input)\t\(exact)\n",
            verbText: verbText
        )
        var history = CandidateSelectionHistory()

        let initial = source.candidates(for: .init(
            input: input,
            conversionReading: input,
            selectionHistory: history
        ))
        #expect(initial.first?.storageText == exact)

        history.record(generated, reading: input)
        let afterOneSelection = source.candidates(for: .init(
            input: input,
            conversionReading: input,
            selectionHistory: history
        ))
        #expect(afterOneSelection.first?.storageText == exact)

        history.record(generated, reading: input)
        let learned = source.candidates(for: .init(
            input: input,
            conversionReading: input,
            selectionHistory: history
        ))
        let promoted = try #require(learned.first)
        #expect(promoted.storageText == generated)
        #expect(promoted.hasSource(.automaticKana))
        #expect(!promoted.hasSource(.selectionHistory))

        let saved = try JSONEncoder().encode(history)
        var restored = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: saved
        )
        #expect(source.candidates(for: .init(
            input: input,
            conversionReading: input,
            selectionHistory: restored
        )).first?.storageText == generated)

        restored.remove([generated])
        #expect(source.candidates(for: .init(
            input: input,
            conversionReading: input,
            selectionHistory: restored
        )).first?.storageText == exact)

        restored.record(generated, reading: input)
        restored.record(generated, reading: input)
        #expect(source.candidates(for: .init(
            input: input,
            conversionReading: input,
            selectionHistory: restored
        )).first?.storageText == generated)
    }

    @Test
    func repeatedSelectionPromotesVerbInflectionWithoutReclassifyingIt() throws {
        let input = "arimasu"
        let generated = "有ります"
        let source = makeSource(
            systemText: "arimasu\tアリマス\n",
            verbText: "aru\t有る\tgodan\t0\n"
        )
        var history = CandidateSelectionHistory()
        history.record(generated, reading: input)
        history.record(generated, reading: input)

        let promoted = try #require(source.candidates(for: .init(
            input: input,
            conversionReading: input,
            selectionHistory: history
        )).first)

        #expect(promoted.storageText == generated)
        #expect(promoted.hasSource(.verbInflection))
        #expect(!promoted.hasSource(.selectionHistory))
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

@Suite
struct DirectTimeSpecialConversionTests {
    /// 1300 is also a number, so its time formats join the numeric ones
    @Test
    func joinsTimeFormatsToNumericCandidates() throws {
        let result = try #require(SpecialConversionCandidateSource().result(
            for: .init(
                input: "1300",
                javaScriptCandidates: [
                    .init(value: "13時0分"),
                    .init(value: "13:00")
                ]
            )
        ))
        let candidates = result.candidates.map(\.storageText)

        #expect(candidates.contains("13:00"))
        #expect(candidates.contains("13時0分"))
        #expect(candidates.contains("1,300"))
        #expect(!candidates.contains("1300"))
    }
}
