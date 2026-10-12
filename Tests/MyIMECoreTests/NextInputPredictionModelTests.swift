import Foundation
import Testing
@testable import MyIMECore

@Suite
struct NextInputPredictionModelTests {
    @Test
    func learnsFollowingInput() {
        var model = NextInputPredictionModel()
        model.record("構造計画研究所")
        model.record("について")
        model.record("構造計画研究所")
        model.record("について")

        #expect(
            model.candidates(after: "構造計画研究所") == ["について"]
        )
    }

    @Test
    func returnsCandidatesForCurrentContext() {
        var model = NextInputPredictionModel()
        model.record("構造")
        model.record("計画")
        model.breakSequence()
        model.record("構造")

        #expect(model.candidatesAfterLastInput() == ["計画"])
    }

    @Test
    func prioritizesMostRecentFollower() {
        var model = NextInputPredictionModel()
        model.record("A")
        model.record("B")
        model.record("A")
        model.record("B")
        model.record("A")
        model.record("C")

        #expect(model.candidates(after: "A") == ["C", "B"])
    }

    @Test
    func ordersEveryCandidateByMostRecentUse() {
        var model = NextInputPredictionModel()
        for follower in ["B", "B", "B", "D", "C"] {
            model.record("A")
            model.record(follower)
            model.breakSequence()
        }

        #expect(model.candidates(after: "A") == ["C", "D", "B"])
    }

    @Test
    func retainsMostRecentFollowerWhenPruning() {
        var model = NextInputPredictionModel()
        for index in 0..<NextInputPredictionModel.maximumFollowersPerContext {
            for _ in 0..<2 {
                model.record("A")
                model.record("候補\(index)")
                model.breakSequence()
            }
        }
        model.record("A")
        model.record("直前候補")

        #expect(model.candidates(after: "A", limit: 30).contains("直前候補"))
    }

    @Test
    func prunesOldContextsAndLowPriorityFollowers() {
        var model = NextInputPredictionModel()
        for index in 0...NextInputPredictionModel.maximumContextCount {
            model.record("文脈\(index)")
            model.record("候補\(index)")
            model.breakSequence()
        }
        for index in 0...NextInputPredictionModel.maximumFollowersPerContext {
            model.record("共通")
            model.record("候補\(index)")
            model.breakSequence()
        }

        #expect(model.contextCount == NextInputPredictionModel.maximumContextCount)
        #expect(
            model.candidates(after: "共通", limit: 30).count
                == NextInputPredictionModel.maximumFollowersPerContext
        )
        #expect(model.candidates(after: "文脈0").isEmpty)
        #expect(model.candidates(after: "共通").first == "候補16")
    }

    @Test
    func clearsLearnedData() {
        var model = NextInputPredictionModel()
        model.record("A")
        model.record("B")
        model.removeAll()

        #expect(model.candidates(after: "A").isEmpty)
        #expect(model.contextCount == 0)
        #expect(model.lastInput == nil)
    }

    @Test
    func suppressesADeletedCandidateForEveryContext() {
        var model = NextInputPredictionModel()
        model.record("よろしく")
        model.record("お願いします")
        model.breakSequence()
        model.record("確認")
        model.record("お願いします")
        model.suppress("お願いします", after: "よろしく")

        #expect(model.candidates(after: "よろしく").isEmpty)
        #expect(model.candidates(after: "確認").isEmpty)
        #expect(model.isSuppressed("お願いします", after: "よろしく"))
        #expect(model.isSuppressed("お願いします", after: "別の文脈"))
    }

    @Test
    func persistsSuppressedCandidates() throws {
        var model = NextInputPredictionModel()
        model.suppress("円", after: "100")

        let restored = try JSONDecoder().decode(
            NextInputPredictionModel.self,
            from: JSONEncoder().encode(model)
        )

        #expect(restored.isSuppressed("円", after: "100"))
    }

    @Test
    func migratesContextualSuppressionToGlobalSuppression() throws {
        let data = Data("""
        {
          "contexts": {},
          "sequence": 0,
          "lastInput": null,
          "suppressedCandidates": {
            "100": ["円"],
            "200": ["個", "円"]
          }
        }
        """.utf8)

        let restored = try JSONDecoder().decode(
            NextInputPredictionModel.self,
            from: data
        )

        #expect(restored.isSuppressed("円", after: "別の文脈"))
        #expect(restored.isSuppressed("個", after: "別の文脈"))
    }

    @Test
    func ignoresOversizedValue() {
        var model = NextInputPredictionModel()
        model.record(String(repeating: "a", count: 81))

        #expect(model.lastInput == nil)
        #expect(model.contextCount == 0)
    }

    @Test
    func breaksSequenceWithoutDeletingLearning() {
        var model = NextInputPredictionModel()
        model.record("A")
        model.record("B")
        model.breakSequence()
        model.record("C")

        #expect(model.candidates(after: "A") == ["B"])
        #expect(model.candidates(after: "B").isEmpty)
    }

    @Test
    func doesNotLearnFirstInputAfterLineBreakAsFollower() {
        var model = NextInputPredictionModel()
        model.record("改行前")
        model.breakSequence()
        model.record("次の行")

        #expect(model.candidates(after: "改行前").isEmpty)
        #expect(model.lastInput == "次の行")
    }

    @Test
    func forgetsAClosingBracketWithoutSuppressingStructuralCandidate() {
        var model = NextInputPredictionModel()
        model.record("本文")
        model.record("）")
        model.breakSequence()

        #expect(model.candidates(after: "本文") == ["）"])

        model.forgetLearnedCandidate("）")

        #expect(model.candidates(after: "本文").isEmpty)
        #expect(!model.isSuppressed("）", after: "本文"))
    }

    @Test
    func suggestsFrequentlyRepeatedCommitSequenceAsOneCandidate() {
        var model = NextInputPredictionModel()
        record(["実装", "に", "進んで"], repetitions: 3, in: &model)

        let predictions = model.predictions(after: "実装", limit: 16)

        #expect(predictions.first?.text == "に進んで")
        #expect(predictions.first?.sourceTokens == ["に", "進んで"])
        #expect(predictions.contains { $0.text == "に" })
    }

    @Test
    func suggestsOnlyTheUncommittedSuffixForLongerContext() {
        var model = NextInputPredictionModel()
        record(["実装", "に", "進んで"], repetitions: 3, in: &model)

        let predictions = model.predictions(
            after: ["実装", "に"],
            limit: 16
        )

        #expect(predictions.first?.text == "進んで")
        #expect(predictions.first?.sourceTokens == ["進んで"])
        #expect(!predictions.contains { $0.text == "に進んで" })
    }

    @Test
    func learnsVariableLengthContinuation() {
        var model = NextInputPredictionModel()
        record(
            ["実装", "に", "進んで", "ください"],
            repetitions: 3,
            in: &model
        )

        #expect(
            model.predictions(after: "実装", limit: 16).contains {
                $0.text == "に進んでください"
                    && $0.sourceTokens == ["に", "進んで", "ください"]
            }
        )
    }

    @Test
    func doesNotExposeOneOffMultiTokenSequence() {
        var model = NextInputPredictionModel()
        model.record(tokens: ["実装", "に", "進んで"])

        #expect(!model.candidates(after: "実装").contains("に進んで"))
        #expect(model.candidates(after: "実装").contains("に"))
    }

    @Test
    func ranksRecentSequenceAheadOfMoreFrequentSequence() {
        var model = NextInputPredictionModel()
        record(["実装", "に", "進んで"], repetitions: 6, in: &model)
        record(["実装", "を", "行う"], repetitions: 3, in: &model)

        let candidates = model.candidates(after: "実装", limit: 16)

        #expect(index(of: "を行う", in: candidates) < index(
            of: "に進んで",
            in: candidates
        ))
    }

    @Test
    func longerMatchingContextDoesNotOutrankMoreRecentUse() {
        var model = NextInputPredictionModel()
        record(
            ["修正", "の", "実装", "に", "進んで"],
            repetitions: 3,
            in: &model
        )
        record(["実装", "を", "確認"], repetitions: 3, in: &model)

        let candidates = model.candidates(
            after: ["修正", "の", "実装"],
            limit: 16
        )

        #expect(candidates.first == "を確認")
        #expect(candidates.contains("に進んで"))
    }

    @Test
    func sequenceBoundaryPreventsCrossBoundaryPrediction() {
        var model = NextInputPredictionModel()
        for _ in 0..<3 {
            model.record("実装")
            model.breakSequence()
            model.record("に")
            model.record("進んで")
            model.breakSequence()
        }

        #expect(model.candidates(after: "実装").isEmpty)
    }

    @Test
    func persistsVariableLengthPredictions() throws {
        var model = NextInputPredictionModel()
        record(["実装", "に", "進んで"], repetitions: 3, in: &model)

        let restored = try JSONDecoder().decode(
            NextInputPredictionModel.self,
            from: JSONEncoder().encode(model)
        )

        #expect(restored.candidates(after: "実装").contains("に進んで"))
    }

    @Test
    func findsLearnedCompoundAcrossTokenBoundariesByReadingPrefix() {
        var model = NextInputPredictionModel()
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            model.record(learningTokens: [
                NextInputLearningToken(text: "東京都", reading: "toukyouto"),
                NextInputLearningToken(text: "中野区", reading: "nakanoku")
            ])
            model.breakSequence()
        }

        for prefix in ["toukyouto", "toukyoutonaka", "toukyoutonakano"] {
            let prediction = model.learnedCompoundPredictions(
                matchingPrefix: prefix
            ).first
            #expect(prediction?.text == "東京都中野区")
            #expect(prediction?.reading == "toukyoutonakanoku")
            #expect(prediction?.sourceTokens == ["東京都", "中野区"])
        }
    }

    @Test
    func findsThreeAndFourTokenLearnedCompounds() {
        var model = NextInputPredictionModel()
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            model.record(learningTokens: [
                NextInputLearningToken(text: "開発", reading: "kaihatsu"),
                NextInputLearningToken(text: "環境", reading: "kankyou"),
                NextInputLearningToken(text: "設定", reading: "settei"),
                NextInputLearningToken(text: "確認", reading: "kakunin")
            ])
            model.breakSequence()
        }

        let predictions = model.learnedCompoundPredictions(
            matchingPrefix: "kaihatsukankyouse"
        )

        #expect(predictions.first?.text == "開発環境設定確認")
        #expect(predictions.first?.sourceTokens.count == 4)
    }

    @Test
    func doesNotFindACompoundBeforeTheLearningThreshold() {
        var model = NextInputPredictionModel()
        for _ in 0..<(NextInputPredictionModel.minimumDirectSequenceCount - 1) {
            model.record(learningTokens: [
                NextInputLearningToken(text: "よろしく", reading: "yoroshiku"),
                NextInputLearningToken(
                    text: "お願いします",
                    reading: "onegaishimasu"
                )
            ])
            model.breakSequence()
        }

        #expect(model.learnedCompoundPredictions(
            matchingPrefix: "yoroshiku"
        ).isEmpty)
    }

    @Test
    func doesNotGuessMissingReadingsOrMatchAnUnrelatedPrefix() {
        var model = NextInputPredictionModel()
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            model.record(tokens: ["東京都", "中野区"])
            model.breakSequence()
        }

        #expect(model.learnedCompoundPredictions(
            matchingPrefix: "toukyouto"
        ).isEmpty)
        #expect(model.learnedCompoundPredictions(
            matchingPrefix: "oosaka"
        ).isEmpty)
    }

    @Test
    func ignoresAnExtremelyShortPrefixAndVisibleCandidate() {
        var model = NextInputPredictionModel()
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            model.record(learningTokens: [
                NextInputLearningToken(text: "東京都", reading: "toukyouto"),
                NextInputLearningToken(text: "中野区", reading: "nakanoku")
            ])
            model.breakSequence()
        }

        #expect(model.learnedCompoundPredictions(matchingPrefix: "to").isEmpty)
        #expect(model.learnedCompoundPredictions(
            matchingPrefix: "toukyouto",
            excluding: ["東京都中野区"]
        ).isEmpty)
    }

    @Test
    func acceptedSelectionsPromoteAReadingBackedCompound() {
        var model = NextInputPredictionModel()
        for _ in 0..<NextInputPredictionModel.minimumEpisodePromotionCount {
            model.record(learningTokens: [
                NextInputLearningToken(text: "東京都", reading: "toukyouto")
            ])
            model.record(
                learningTokens: [
                    NextInputLearningToken(text: "中野区", reading: "nakanoku")
                ],
                source: .acceptedCandidate
            )
            model.breakSequence()
        }

        #expect(model.learnedCompoundPredictions(
            matchingPrefix: "toukyoutonaka"
        ).first?.text == "東京都中野区")
    }

    @Test
    func learnedCompoundReadingSurvivesPersistence() throws {
        var model = NextInputPredictionModel()
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            model.record(learningTokens: [
                NextInputLearningToken(text: "ABC", reading: "abc"),
                NextInputLearningToken(text: "123", reading: "123")
            ])
            model.breakSequence()
        }
        let restored = try JSONDecoder().decode(
            NextInputPredictionModel.self,
            from: JSONEncoder().encode(model)
        )

        #expect(restored.learnedCompoundPredictions(
            matchingPrefix: "abc"
        ).first?.text == "ABC123")
    }

    @Test
    func selectingAnExistingCombinedCompoundDoesNotGrowIt() {
        var model = NextInputPredictionModel()
        let tokens = [
            NextInputLearningToken(text: "開発", reading: "kaihatsu"),
            NextInputLearningToken(text: "環境", reading: "kankyou"),
            NextInputLearningToken(text: "設定", reading: "settei")
        ]
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            model.record(learningTokens: tokens)
            model.breakSequence()
        }
        for _ in 0..<8 {
            model.record(learningTokens: [
                NextInputLearningToken(text: "前置き", reading: "maeoki")
            ])
            model.record(
                learningTokens: tokens,
                source: .acceptedCandidate
            )
            model.breakSequence()
        }

        let predictions = model.learnedCompoundPredictions(
            matchingPrefix: "maeoki"
        )
        #expect(!predictions.contains { $0.text == "前置き開発環境設定" })
        #expect(model.learnedCompoundPredictions(
            matchingPrefix: "kaihatsu"
        ).first?.text == "開発環境設定")
    }

    @Test
    func suppressesAndRelearnsACompoundOnlyAfterTheFullThreshold() {
        var model = NextInputPredictionModel()
        let tokens = [
            NextInputLearningToken(text: "東京都", reading: "toukyouto"),
            NextInputLearningToken(text: "中野区", reading: "nakanoku")
        ]
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            model.record(learningTokens: tokens)
            model.breakSequence()
        }
        model.suppress("東京都中野区", after: "learnedCompound")

        #expect(model.learnedCompoundPredictions(
            matchingPrefix: "toukyouto"
        ).isEmpty)

        for _ in 0..<(NextInputPredictionModel.minimumDirectSequenceCount - 1) {
            model.record(learningTokens: tokens)
            model.breakSequence()
        }
        #expect(model.learnedCompoundPredictions(
            matchingPrefix: "toukyouto"
        ).isEmpty)

        model.record(learningTokens: tokens)
        model.breakSequence()
        #expect(model.learnedCompoundPredictions(
            matchingPrefix: "toukyouto"
        ).first?.text == "東京都中野区")
    }

    @Test
    func twoAcceptedEpisodesPromoteASequence() {
        var model = NextInputPredictionModel()
        for _ in 0..<2 {
            model.record("実装")
            model.record("に", source: .acceptedCandidate)
            model.record("進んで", source: .acceptedCandidate)
        }

        let prediction = model.predictions(after: "実装").first {
            $0.text == "に進んで"
        }

        #expect(prediction?.sourceTokens == ["に", "進んで"])
    }

    @Test
    func oneAcceptedEpisodeDoesNotPromoteASequence() {
        var model = NextInputPredictionModel()
        for _ in 0..<1 {
            model.record("実装")
            model.record("に", source: .acceptedCandidate)
            model.record("進んで", source: .acceptedCandidate)
        }

        #expect(!model.candidates(after: "実装").contains("に進んで"))
    }

    @Test
    func recentlySelectedEpisodeOutranksOlderDirectSequence() {
        var model = NextInputPredictionModel()
        record(["実装", "を", "行う"], repetitions: 6, in: &model)
        for _ in 0..<2 {
            model.record("実装")
            model.record("に", source: .acceptedCandidate)
            model.record("進んで", source: .acceptedCandidate)
        }

        let candidates = model.candidates(after: "実装", limit: 16)

        #expect(index(of: "に進んで", in: candidates) < index(
            of: "を行う",
            in: candidates
        ))
    }

    @Test
    func indexedLookupRemainsBoundedForRepresentativeHistory() {
        var model = NextInputPredictionModel()
        for index in 0..<1_000 {
            model.record(tokens: ["文脈\(index)", "候補", "です"])
            model.breakSequence()
        }
        let start = Date()
        for _ in 0..<10_000 {
            _ = model.candidates(after: "文脈999", limit: 16)
        }

        #expect(Date().timeIntervalSince(start) < 2)
    }

    @Test
    func learnedCompoundPrefixLookupRemainsBounded() {
        var model = NextInputPredictionModel()
        for index in 0..<1_000 {
            for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
                model.record(learningTokens: [
                    NextInputLearningToken(
                        text: "都道府県\(index)",
                        reading: "todoufuken\(index)"
                    ),
                    NextInputLearningToken(
                        text: "市区町村\(index)",
                        reading: "shikuchouson\(index)"
                    )
                ])
                model.breakSequence()
            }
        }
        let start = Date()
        for _ in 0..<10_000 {
            _ = model.learnedCompoundPredictions(
                matchingPrefix: "todoufuken999"
            )
        }

        #expect(Date().timeIntervalSince(start) < 2)
    }

    @Test
    func directRepetitionWithoutSequenceBreaksStillPromotesTheContinuation() {
        var model = NextInputPredictionModel()
        for _ in 0..<3 {
            model.record(tokens: ["実装"])
            model.record(tokens: ["に"])
            model.record(tokens: ["進んで"])
        }

        #expect(model.candidates(after: "実装", limit: 16).contains("に進んで"))
    }

    @Test
    func reselectingACombinedCandidateAloneDoesNotPromoteIt() {
        var model = NextInputPredictionModel()
        for _ in 0..<20 {
            model.record("実装")
            model.record(tokens: ["に", "進んで"], source: .acceptedCandidate)
        }

        #expect(!model.candidates(after: "実装", limit: 16).contains("に進んで"))
    }

    @Test
    func endsAnEpisodeAtASequenceBoundary() {
        var model = NextInputPredictionModel()
        for _ in 0..<12 {
            model.record("実装")
            model.record("に", source: .acceptedCandidate)
            model.breakSequence()
            model.record("進んで", source: .acceptedCandidate)
        }

        #expect(!model.candidates(after: "実装", limit: 16).contains("に進んで"))
    }

    @Test
    func dropsMultiTokenStatisticsSavedBeforeEpisodeSeparation() throws {
        var model = NextInputPredictionModel()
        record(["実装", "に", "進んで"], repetitions: 3, in: &model)
        var json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(model)
        ) as! [String: Any]
        json.removeValue(forKey: "sequenceVersion")

        let restored = try JSONDecoder().decode(
            NextInputPredictionModel.self,
            from: JSONSerialization.data(withJSONObject: json)
        )

        #expect(!restored.candidates(after: "実装", limit: 16).contains("に進んで"))
        #expect(restored.candidates(after: "実装", limit: 16).contains("に"))
        #expect(restored.candidates(after: ["実装", "に"], limit: 16)
            .contains("進んで"))
    }

    @Test
    func repeatedAcceptedEpisodesDoNotLearnTheNextRepetition() {
        var model = NextInputPredictionModel()
        for _ in 0..<12 {
            model.record("実装")
            model.record("に", source: .acceptedCandidate)
            model.record("進んで", source: .acceptedCandidate)
        }

        let texts = model.predictions(after: "実装", limit: 16).map(\.text)

        #expect(texts.contains("に進んで"))
        #expect(!texts.contains("に進んで実装"))
        #expect(!texts.contains("に進んで実装に"))
        #expect(!texts.contains("に進んで実装に進んで"))
        #expect(!model.candidates(after: "進んで", limit: 16)
            .contains("実装に進んで"))
    }

    @Test
    func countsEachAcceptedEpisodeOnceWithoutSequenceBreaks() {
        var model = NextInputPredictionModel()
        for _ in 0..<1 {
            model.record("実装")
            model.record("に", source: .acceptedCandidate)
            model.record("進んで", source: .acceptedCandidate)
        }
        model.record("実装")

        #expect(!model.candidates(after: "実装", limit: 16).contains("に進んで"))

        model.record("に", source: .acceptedCandidate)
        model.record("進んで", source: .acceptedCandidate)
        model.record("実装")

        #expect(model.candidates(after: "実装", limit: 16).contains("に進んで"))
    }

    @Test
    func keepsSentenceTransitionsAcrossAcceptedEpisodes() {
        var model = NextInputPredictionModel()
        for _ in 0..<12 {
            model.record("実装")
            model.record("に", source: .acceptedCandidate)
            model.record("進んで", source: .acceptedCandidate)
        }

        #expect(model.candidates(after: "進んで", limit: 16).contains("実装"))
        #expect(model.candidates(after: "実装", limit: 16).contains("に"))
    }

    @Test
    func doesNotCountMixedSourceSequencesAsDirectEvidence() {
        var model = NextInputPredictionModel()
        for _ in 0..<12 {
            model.record("確認")
            model.record("に", source: .acceptedCandidate)
            model.record("進んで", source: .acceptedCandidate)
            model.record("実装")
        }

        #expect(!model.candidates(after: "確認", limit: 16)
            .contains("に進んで実装"))
    }

    @Test
    func reselectingAPromotedCandidateKeepsItsTokens() {
        var model = NextInputPredictionModel()
        for _ in 0..<2 {
            model.record("実装")
            model.record("に", source: .acceptedCandidate)
            model.record("進んで", source: .acceptedCandidate)
        }
        for _ in 0..<3 {
            model.record("実装")
            model.record(tokens: ["に", "進んで"], source: .acceptedCandidate)
        }
        model.record("実装")

        let prediction = model.predictions(after: "実装", limit: 16).first {
            $0.text == "に進んで"
        }
        #expect(prediction?.sourceTokens == ["に", "進んで"])
        #expect(!model.candidates(after: "実装", limit: 16)
            .contains("に進んで実装"))
    }

    private func record(
        _ tokens: [String],
        repetitions: Int,
        in model: inout NextInputPredictionModel
    ) {
        for _ in 0..<repetitions {
            model.record(tokens: tokens)
            model.breakSequence()
        }
    }

    private func index(of value: String, in candidates: [String]) -> Int {
        candidates.firstIndex(of: value) ?? Int.max
    }
}
