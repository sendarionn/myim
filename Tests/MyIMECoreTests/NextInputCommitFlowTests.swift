import Foundation
import Testing
@testable import MyIMECore

@Suite
struct NextInputCommitFlowTests {
    @Test
    func structuralClosingUpdatesSuggestionsWithoutLearning() {
        var tracker = ClosingBracketTracker()
        tracker.consume("（")

        let policy = NextInputCommitPolicy.resolve(
            committing: "）",
            closingBracketTracker: tracker,
            isGeneratedParticle: false
        )

        #expect(policy == NextInputCommitPolicy(
            learnsInput: false,
            updatesSuggestions: true
        ))
    }

    @Test
    func ordinaryInputLearnsAndUpdatesSuggestions() {
        let policy = NextInputCommitPolicy.resolve(
            committing: "候補",
            closingBracketTracker: ClosingBracketTracker(),
            isGeneratedParticle: false
        )

        #expect(policy == NextInputCommitPolicy(
            learnsInput: true,
            updatesSuggestions: true
        ))
    }

    @Test
    func generatedParticleNeitherLearnsNorUpdatesSuggestions() {
        let policy = NextInputCommitPolicy.resolve(
            committing: "を",
            closingBracketTracker: ClosingBracketTracker(),
            isGeneratedParticle: true
        )

        #expect(policy == NextInputCommitPolicy(
            learnsInput: false,
            updatesSuggestions: false
        ))
    }

    @Test
    func explicitlySelectedGeneratedParticleLearnsAndUpdatesSuggestions() {
        let policy = NextInputCommitPolicy.resolve(
            committing: "に",
            closingBracketTracker: ClosingBracketTracker(),
            isGeneratedParticle: true,
            selectedCandidate: Candidate(
                storageText: "に",
                source: .particleComposition,
                attributes: [.generated]
            )
        )

        #expect(policy == NextInputCommitPolicy(
            learnsInput: true,
            updatesSuggestions: true
        ))
    }

    @Test
    func unrelatedSelectionDoesNotMakeAGeneratedParticleLearnable() {
        let policy = NextInputCommitPolicy.resolve(
            committing: "に",
            closingBracketTracker: ClosingBracketTracker(),
            isGeneratedParticle: true,
            selectedCandidate: Candidate(
                storageText: "別候補",
                source: .basicDictionary
            )
        )

        #expect(policy == NextInputCommitPolicy(
            learnsInput: false,
            updatesSuggestions: false
        ))
    }

    @Test
    func openingBracketOffersItsClosingAsNextInput() {
        let flow = CommitFlow()

        flow.commitInput("（")

        #expect(flow.coordinator.candidates.first == "）")
        #expect(!flow.tracker.shouldRecordAsNextInput("）"))
    }

    @Test
    func committedClosingCandidateDoesNotLeaveItsSessionSelected() {
        let flow = CommitFlow()
        flow.commitInput("（")
        flow.select("）")

        flow.commitSelectedNextInput()

        #expect(flow.text == "（）")
        #expect(flow.coordinator.selectedCandidate == nil)
        #expect(flow.tracker.candidate == nil)
    }

    @Test
    func nextTypedTextFollowsTheCommittedClosingOnce() {
        let flow = CommitFlow()
        flow.commitInput("（")
        flow.select("）")
        flow.commitSelectedNextInput()

        flow.type("a")

        #expect(flow.text == "（）a")
    }

    @Test
    func closingBracketIsNotLearnedAsAFollower() {
        let flow = CommitFlow()
        flow.commitInput("（")
        flow.select("）")
        flow.commitSelectedNextInput()

        flow.commitInput("（")

        #expect(flow.coordinator.candidates == ["）"])
        #expect(flow.coordinator.learnedCandidates(
            after: "（",
            predictionEnabled: true,
            learningEnabled: false,
            breakPreviousSequence: false,
            limit: 16
        ).isEmpty)
    }

    @Test
    func ordinaryCommittedCandidateDoesNotStaySelected() {
        let flow = CommitFlow()
        flow.commitInput("候補")
        flow.commitInput("を")
        flow.commitInput("候補")
        flow.select("を")

        flow.commitSelectedNextInput()
        flow.type("a")

        #expect(flow.text == "候補を候補をa")
        #expect(flow.coordinator.selectedCandidate == nil)
    }

    @Test
    func nestedClosingCandidatesAreOfferedInTurn() {
        let flow = CommitFlow()
        flow.commitInput("（")
        flow.commitInput("「")
        flow.commitInput("本文")
        #expect(flow.coordinator.candidates.first == "」")

        flow.select("」")
        flow.commitSelectedNextInput()

        #expect(flow.coordinator.candidates.first == "）")
        #expect(flow.coordinator.selectedCandidate == nil)

        flow.select("）")
        flow.commitSelectedNextInput()
        flow.type("a")

        #expect(flow.text == "（「本文」）a")
        #expect(flow.tracker.candidate == nil)
    }

    @Test
    func acceptedSequenceKeepsItsOriginalCommitBoundaries() {
        let flow = CommitFlow()
        for _ in 0..<3 {
            for token in ["A", "B", "C", "D"] {
                flow.commitInput(token)
            }
            flow.breakSequence()
        }
        flow.commitInput("A")
        flow.select("BC")

        flow.commitSelectedNextInput()

        #expect(flow.text.hasSuffix("ABC"))
        #expect(flow.coordinator.candidates.contains("D"))
    }

    @Test
    func repeatedNextInputSelectionsPromoteTheirCommitSequence() {
        let flow = CommitFlow()
        for _ in 0..<2 {
            flow.commitInput("実装")
            flow.offerNextInput("に")
            flow.select("に")
            flow.commitSelectedNextInput()
            flow.offerNextInput("進んで")
            flow.select("進んで")
            flow.commitSelectedNextInput()
            flow.breakSequence()
        }

        flow.commitInput("実装")

        #expect(flow.coordinator.candidates.contains("に進んで"))
    }

    @Test(arguments: [
        (["住所", "東京都", "中野区"], "住所", "東京都中野区"),
        (["挨拶", "よろしく", "お願いします"], "挨拶", "よろしくお願いします"),
        (["実装", "を", "確認する"], "実装", "を確認する"),
        (["本日", "の", "会議", "資料"], "本日", "の会議資料"),
        (["種類", "ABC", "123"], "種類", "ABC123")
    ])
    func repeatedDirectCommitsProduceCombinedContinuations(
        sequence: [String],
        context: String,
        expected: String
    ) {
        let flow = CommitFlow()
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            for token in sequence {
                flow.commitInput(token)
            }
            flow.breakSequence()
        }

        flow.commitInput(context)

        #expect(flow.coordinator.candidates.contains(expected))
    }

    @Test
    func directSequenceBelowTheThresholdIsNotCombined() {
        let flow = CommitFlow()
        for _ in 0..<(NextInputPredictionModel.minimumDirectSequenceCount - 1) {
            for token in ["実装", "を", "確認する"] {
                flow.commitInput(token)
            }
            flow.breakSequence()
        }

        flow.commitInput("実装")

        #expect(!flow.coordinator.candidates.contains("を確認する"))
    }

    @Test
    func fiveUnitSequenceOffersAtMostFourFollowingUnits() {
        let flow = CommitFlow()
        let sequence = ["東京", "大阪", "名古屋", "京都", "神戸"]
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            for token in sequence {
                flow.commitInput(token)
            }
            flow.breakSequence()
        }

        flow.commitInput("東京")

        let combined = flow.coordinator.candidateModels.first {
            $0.commitText == "大阪名古屋京都神戸"
        }
        #expect(combined.flatMap(NextInputCandidateMetadata.sourceTokens)
            == ["大阪", "名古屋", "京都", "神戸"])
        #expect(!flow.coordinator.candidates.contains(
            "東京大阪名古屋京都神戸"
        ))
    }

    @Test
    func combinedContinuationDoesNotExceedTheMaximumLength() {
        let flow = CommitFlow()
        let first = String(repeating: "東", count: 41)
        let second = String(repeating: "京", count: 40)
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            for token in ["住所", first, second] {
                flow.commitInput(token)
            }
            flow.breakSequence()
        }

        flow.commitInput("住所")

        #expect(!flow.coordinator.candidates.contains(first + second))
        #expect(flow.coordinator.candidates.allSatisfy {
            $0.count <= NextInputPredictionModel.maximumValueLength
        })
    }

    @Test
    func repeatedlySelectingACombinedFourUnitCandidateDoesNotGrowIt() {
        let flow = CommitFlow()
        let tokens = ["環境", "設定", "確認", "完了"]
        for _ in 0..<NextInputPredictionModel.minimumEpisodePromotionCount {
            flow.commitInput("開発")
            for token in tokens {
                flow.offerNextInput(token)
                flow.selectAndCommit(token)
            }
            flow.breakSequence()
        }
        for _ in 0..<5 {
            flow.commitInput("開発")
            flow.selectAndCommit("環境設定確認完了")
            flow.breakSequence()
        }

        flow.commitInput("開発")

        #expect(flow.coordinator.candidates.contains("環境設定確認完了"))
        #expect(flow.coordinator.candidates.allSatisfy {
            !$0.contains("環境設定確認完了開発")
        })
    }

    @Test
    func repeatedSelectionsWithoutBreaksDoNotAppendTheNextRepetition() {
        let flow = CommitFlow()
        for _ in 0..<12 {
            flow.commitInput("実装")
            flow.offerNextInput("に")
            flow.select("に")
            flow.commitSelectedNextInput()
            flow.offerNextInput("進んで")
            flow.select("進んで")
            flow.commitSelectedNextInput()
        }
        flow.commitInput("実装")

        #expect(flow.coordinator.candidates.contains("に進んで"))
        #expect(!flow.coordinator.candidates.contains("に進んで実装"))
        #expect(!flow.coordinator.candidates.contains("に進んで実装に"))
    }

    @Test
    func selectedGeneratedParticleContributesToACommitSequence() {
        let flow = CommitFlow()
        for _ in 0..<3 {
            flow.commitInput("実装")
            flow.commitInput(
                "に",
                isGeneratedParticle: true,
                selectedCandidate: Candidate(
                    storageText: "に",
                    source: .particleComposition,
                    attributes: [.generated]
                )
            )
            flow.commitInput("進んで")
            flow.breakSequence()
        }

        flow.commitInput("実装")

        #expect(flow.coordinator.candidates.contains("に進んで"))
    }

    @Test
    func unselectedGeneratedParticleDoesNotJoinACommitSequence() {
        let flow = CommitFlow()
        for _ in 0..<3 {
            flow.commitInput("実装")
            flow.commitInput("に", isGeneratedParticle: true)
            flow.commitInput("進んで")
        }

        flow.commitInput("実装")

        #expect(!flow.coordinator.candidates.contains("に進んで"))
    }

    @Test
    func oneRealSelectionRunIsNotCombined() {
        let flow = CommitFlow.seededWithImplementationFollowers()

        flow.commitInput("実装")
        flow.selectAndCommit("に")
        flow.selectAndCommit("進んで")
        flow.commitInput("実装")

        #expect(!flow.coordinator.candidates.contains("に進んで"))
    }

    @Test
    func twoRealSelectionRunsAreCombinedWithTheirTokens() {
        let flow = CommitFlow.seededWithImplementationFollowers()

        for _ in 0..<2 {
            flow.commitInput("実装")
            flow.selectAndCommit("に")
            flow.selectAndCommit("進んで")
        }
        flow.commitInput("実装")

        let combined = flow.coordinator.candidateModels.first {
            $0.commitText == "に進んで"
        }
        #expect(combined.flatMap(NextInputCandidateMetadata.sourceTokens)
            == ["に", "進んで"])
    }

    @Test
    func combinedCandidateComesFirstAfterItsSelection() {
        let flow = CommitFlow.seededWithImplementationFollowers()
        for _ in 0..<2 {
            flow.commitInput("実装")
            flow.selectAndCommit("に")
            flow.selectAndCommit("進んで")
        }
        flow.commitInput("実装")
        flow.selectAndCommit("を")
        flow.commitInput("実装")
        flow.selectAndCommit("に進んで")

        flow.commitInput("実装")

        #expect(flow.coordinator.candidates.first == "に進んで")
    }

    @Test
    func deletedCombinedCandidateReturnsAfterTwoNewSelectionRuns() throws {
        let flow = CommitFlow.seededWithImplementationFollowers()
        for _ in 0..<2 {
            flow.commitInput("実装")
            flow.selectAndCommit("に")
            flow.selectAndCommit("進んで")
        }
        flow.commitInput("実装")
        flow.select("に進んで")
        try flow.coordinator.suppressSelectedCandidate()
        flow.commitInput("、")

        for _ in 0..<2 {
            flow.commitInput("実装")
            flow.selectAndCommit("に")
            flow.selectAndCommit("進んで")
        }
        flow.commitInput("実装")

        #expect(flow.coordinator.candidates.contains("に進んで"))
    }

    @Test
    func deletedCombinedCandidateStaysHiddenAfterOneNewSelectionRun() throws {
        let flow = CommitFlow.seededWithImplementationFollowers()
        for _ in 0..<2 {
            flow.commitInput("実装")
            flow.selectAndCommit("に")
            flow.selectAndCommit("進んで")
        }
        flow.commitInput("実装")
        flow.select("に進んで")
        try flow.coordinator.suppressSelectedCandidate()
        flow.commitInput("、")

        flow.commitInput("実装")
        flow.selectAndCommit("に")
        flow.selectAndCommit("進んで")
        flow.commitInput("実装")

        #expect(!flow.coordinator.candidates.contains("に進んで"))
    }

    @Test
    func committedReadingsExposeTheWholePhraseToFuzzyPrefixSearch() {
        let flow = CommitFlow()
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            flow.commitInput("東京都", reading: "toukyouto")
            flow.commitInput("中野区", reading: "nakanoku")
            flow.breakSequence()
        }

        let prediction = flow.coordinator.learnedCompoundPredictions(
            matchingPrefix: "toukyoutonaka",
            excluding: []
        ).first

        #expect(prediction?.text == "東京都中野区")
        #expect(prediction?.sourceTokens == ["東京都", "中野区"])
    }

    /// The usual repetition: 東京都 is converted, then 中野区 is picked from
    /// the next-input suggestions learned from one typed occurrence
    @Test
    func selectingTheSuggestedFollowerLearnsThePhraseForPrefixSearch() {
        let flow = CommitFlow.seededWithTypedTokyoNakano()
        for _ in 0..<NextInputPredictionModel.minimumEpisodePromotionCount {
            flow.commitInput("東京都", reading: "toukyouto")
            flow.selectAndCommit("中野区")
            flow.commitInput("。")
        }

        for input in ["toukyouto", "toukyoutonaka"] {
            let prediction = flow.coordinator.learnedCompoundPredictions(
                matchingPrefix: input,
                excluding: ["東京都"]
            ).first
            #expect(prediction?.text == "東京都中野区")
            #expect(prediction?.sourceTokens == ["東京都", "中野区"])
            #expect(prediction?.sourceReadings == ["toukyouto", "nakanoku"])
        }
    }

    @Test
    func oneSelectedFollowerDoesNotLearnThePhraseYet() {
        let flow = CommitFlow.seededWithTypedTokyoNakano()
        flow.commitInput("東京都", reading: "toukyouto")
        flow.selectAndCommit("中野区")
        flow.commitInput("。")

        #expect(flow.coordinator.learnedCompoundPredictions(
            matchingPrefix: "toukyouto",
            excluding: []
        ).isEmpty)
    }

    @Test
    func committingThePhraseLearnedFromSelectionsKeepsItsBoundaries() {
        let flow = CommitFlow.seededWithTypedTokyoNakano()
        for _ in 0..<NextInputPredictionModel.minimumEpisodePromotionCount {
            flow.commitInput("東京都", reading: "toukyouto")
            flow.selectAndCommit("中野区")
            flow.commitInput("。")
        }
        let prediction = flow.coordinator.learnedCompoundPredictions(
            matchingPrefix: "toukyoutonaka",
            excluding: []
        ).first
        let textBeforeCommit = flow.text

        flow.commitLearnedCompound(prediction)

        #expect(flow.text == textBeforeCommit + "東京都中野区")
        #expect(flow.coordinator.learnedCompoundPredictions(
            matchingPrefix: "toukyouto",
            excluding: []
        ).map(\.text) == ["東京都中野区"])
    }

    @Test
    func committingLearnedCompoundKeepsItsOriginalBoundaries() {
        let flow = CommitFlow()
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            flow.commitInput("開発", reading: "kaihatsu")
            flow.commitInput("環境", reading: "kankyou")
            flow.commitInput("設定", reading: "settei")
            flow.breakSequence()
        }
        let prediction = flow.coordinator.learnedCompoundPredictions(
            matchingPrefix: "kaihatsukankyou",
            excluding: []
        ).first
        let textBeforeCommit = flow.text

        flow.commitLearnedCompound(prediction)

        #expect(flow.text == textBeforeCommit + "開発環境設定")
        #expect(flow.coordinator.learnedCompoundPredictions(
            matchingPrefix: "kaihatsu",
            excluding: []
        ).first?.sourceTokens == ["開発", "環境", "設定"])
    }
}

/// Mirrors the order InputController uses when committing text so the
/// next-input session lifecycle can be checked without InputMethodKit
private final class CommitFlow {
    private(set) var text = ""
    private(set) var tracker = ClosingBracketTracker()
    let coordinator = NextInputSuggestionCoordinator(
        predictionModel: NextInputPredictionModel(),
        writer: DeferredJSONFileWriter(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathComponent("next-input.json"),
            delay: 60,
            queueLabel: "myim.next-input-commit-flow-test"
        )
    )

    func commitInput(
        _ value: String,
        learningTokens: [String]? = nil,
        learningReadings: [String?]? = nil,
        reading: String? = nil,
        learningSource: NextInputLearningSource = .directInput,
        isGeneratedParticle: Bool = false,
        selectedCandidate: Candidate? = nil
    ) {
        let policy = NextInputCommitPolicy.resolve(
            committing: value,
            closingBracketTracker: tracker,
            isGeneratedParticle: isGeneratedParticle,
            selectedCandidate: selectedCandidate
        )
        text += value
        tracker.consume(value)
        guard policy.updatesSuggestions else { return }
        let structural = tracker.candidate.map { [$0] } ?? []
        let committedTokens = learningTokens ?? [value]
        let committedReadings = learningReadings?.count == committedTokens.count
            ? learningReadings ?? []
            : [reading] + Array(
                repeating: nil,
                count: max(0, committedTokens.count - 1)
            )
        coordinator.beginSuggestions(
            context: committedTokens.last ?? value,
            preferredCandidates: structural.map {
                Candidate(storageText: $0, source: .nextInput)
            },
            learnedCandidates: coordinator.learnedCandidateModels(
                after: value,
                committedTokens: zip(
                    committedTokens,
                    committedReadings
                ).map {
                    NextInputLearningToken(text: $0.0, reading: $0.1)
                },
                learningSource: learningSource,
                predictionEnabled: true,
                learningEnabled: policy.learnsInput,
                breakPreviousSequence: false,
                limit: 16
            ),
            dictionaryCandidates: [],
            unsuppressibleCandidates: Set(structural.filter {
                tracker.shouldBypassCandidateSuppression($0)
            })
        )
    }

    func select(_ candidate: String) {
        guard let index = coordinator.candidates.firstIndex(of: candidate)
        else {
            Issue.record("\(candidate) is not a next-input candidate")
            return
        }
        coordinator.select(index: index)
    }

    func offerNextInput(_ value: String) {
        coordinator.beginSuggestions(
            context: coordinator.context ?? "",
            preferredCandidates: [],
            learnedCandidates: [NextInputCandidateMetadata.candidate(
                from: NextInputPrediction(text: value, sourceTokens: [value])
            )],
            dictionaryCandidates: []
        )
    }

    func commitSelectedNextInput() {
        guard let value = coordinator.selectedCandidate else { return }
        let sourceTokens = coordinator.selectedSourceTokens
        let sourceReadings = coordinator.selectedSourceReadings
        coordinator.resetSuggestions()
        commitInput(
            value,
            learningTokens: sourceTokens,
            learningReadings: sourceReadings,
            learningSource: .acceptedSuggestion
        )
    }

    func commitLearnedCompound(_ prediction: LearnedCompoundPrediction?) {
        guard let prediction else {
            Issue.record("learned compound is missing")
            return
        }
        commitInput(
            prediction.text,
            learningTokens: prediction.sourceTokens,
            learningReadings: prediction.sourceReadings,
            learningSource: .acceptedSuggestion
        )
    }

    /// Typed history that makes に, を and 進んで real next-input
    /// candidates without ever following 実装 with に進んで
    static func seededWithImplementationFollowers() -> CommitFlow {
        let flow = CommitFlow()
        for token in ["実装", "を", "。", "実装", "に", "。", "確認", "に", "進んで", "。"] {
            flow.commitInput(token)
        }
        return flow
    }

    /// 東京都 and 中野区 typed once, so 中野区 is offered after 東京都
    /// without the pair being learned as a phrase
    static func seededWithTypedTokyoNakano() -> CommitFlow {
        let flow = CommitFlow()
        flow.commitInput("東京都", reading: "toukyouto")
        flow.commitInput("中野区", reading: "nakanoku")
        flow.commitInput("。")
        return flow
    }

    /// Selects a candidate the coordinator really offers and commits it
    func selectAndCommit(_ candidate: String) {
        select(candidate)
        commitSelectedNextInput()
    }

    func type(_ characters: String) {
        commitSelectedNextInput()
        coordinator.resetSuggestions()
        text += characters
    }

    func breakSequence() {
        coordinator.breakSequence()
    }
}
