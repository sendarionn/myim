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
        coordinator.beginSuggestions(
            context: committedTokens.last ?? value,
            preferredCandidates: structural.map {
                Candidate(storageText: $0, source: .nextInput)
            },
            learnedCandidates: coordinator.learnedCandidateModels(
                after: value,
                committedTokens: committedTokens,
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
        coordinator.resetSuggestions()
        commitInput(
            value,
            learningTokens: sourceTokens,
            learningSource: .acceptedSuggestion
        )
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
