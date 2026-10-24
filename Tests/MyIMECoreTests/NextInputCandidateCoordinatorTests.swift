import Foundation
import Testing
@testable import MyIMECore

@Suite
struct NextInputCandidateCoordinatorTests {
    @Test
    func ownsLearningCandidateStateAndPersistence() throws {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        _ = fixture.coordinator.learnedCandidates(
            after: "候補",
            predictionEnabled: true,
            learningEnabled: true,
            breakPreviousSequence: false,
            limit: 16
        )
        _ = fixture.coordinator.learnedCandidates(
            after: "を",
            predictionEnabled: true,
            learningEnabled: true,
            breakPreviousSequence: false,
            limit: 16
        )
        let candidates = fixture.coordinator.learnedCandidates(
            after: "候補",
            predictionEnabled: true,
            learningEnabled: false,
            breakPreviousSequence: false,
            limit: 16
        )
        fixture.coordinator.flush()

        let saved = try JSONDecoder().decode(
            NextInputPredictionModel.self,
            from: Data(contentsOf: fixture.fileURL)
        )
        #expect(candidates == ["を"])
        #expect(saved.candidates(after: "候補") == ["を"])
    }

    @Test
    func filtersSuppressedCandidatesExceptStructuralPreferences() throws {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let coordinator = fixture.coordinator
        coordinator.beginCandidates(
            context: "開く",
            preferredCandidates: ["」"],
            learnedCandidates: [],
            dictionaryCandidates: []
        )
        _ = coordinator.select(index: 0)
        try coordinator.suppressSelectedCandidate()

        coordinator.beginCandidates(
            context: "開く",
            preferredCandidates: ["」"],
            learnedCandidates: [],
            dictionaryCandidates: ["」", "閉じる"]
        )
        #expect(coordinator.candidates == ["閉じる"])

        coordinator.beginCandidates(
            context: "開く",
            preferredCandidates: ["」"],
            learnedCandidates: [],
            dictionaryCandidates: ["閉じる"],
            unsuppressibleCandidates: ["」"]
        )
        #expect(coordinator.candidates == ["」", "閉じる"])
    }

    @Test
    func appendsAsyncCandidatesWithoutLosingSelection() {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let coordinator = fixture.coordinator
        coordinator.beginCandidates(
            context: "候補",
            preferredCandidates: [],
            learnedCandidates: ["A", "B"],
            dictionaryCandidates: []
        )
        _ = coordinator.select(index: 1)

        let changed = coordinator.appendGeneratedCandidates(
            ["B", "C"],
            after: "候補"
        )

        #expect(changed)
        #expect(coordinator.candidates == ["A", "B", "C"])
        #expect(coordinator.selectedCandidate == "B")
        #expect(coordinator.selectedIndex == 1)
    }

    @Test
    func limitsInitialCandidatesToOneFourItemPage() {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let coordinator = fixture.coordinator

        let hasCandidates = coordinator.beginCandidates(
            context: "候補",
            preferredCandidates: ["優先"],
            learnedCandidates: ["A", "B", "C", "D"],
            dictionaryCandidates: ["E"]
        )

        #expect(hasCandidates)
        #expect(coordinator.candidates == ["優先", "A", "B", "C"])
        #expect(coordinator.pageRange(pageSize: 4) == 0..<4)
        #expect(coordinator.wrappedSelectionIndex(offset: 1) == 0)
        _ = coordinator.select(index: 3)
        #expect(coordinator.wrappedSelectionIndex(offset: 1) == 0)
    }

    @Test
    func cyclesTabAndArrowsWithinOnlyTwoCandidates() {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let coordinator = fixture.coordinator
        coordinator.beginCandidates(
            context: "候補",
            preferredCandidates: [],
            learnedCandidates: ["A", "B"],
            dictionaryCandidates: []
        )

        #expect(coordinator.wrappedSelectionIndex(offset: 1) == 0)
        _ = coordinator.select(index: 0)
        #expect(coordinator.wrappedSelectionIndex(offset: 1) == 1)
        #expect(coordinator.linearSelectionIndex(offset: -1) == 1)
        _ = coordinator.select(index: 1)
        #expect(coordinator.wrappedSelectionIndex(offset: 1) == 0)
        #expect(coordinator.linearSelectionIndex(offset: 1) == 0)
    }

    @Test
    func fillsOnlyEmptySlotsWithAsyncCandidatesAndKeepsSelection() {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let coordinator = fixture.coordinator
        coordinator.beginCandidates(
            context: "候補",
            preferredCandidates: [],
            learnedCandidates: ["A", "B"],
            dictionaryCandidates: []
        )
        _ = coordinator.select(index: 1)

        let changed = coordinator.appendGeneratedCandidates(
            ["C", "D", "E"],
            after: "候補"
        )

        #expect(changed)
        #expect(coordinator.candidates == ["A", "B", "C", "D"])
        #expect(coordinator.selectedCandidate == "B")
        #expect(coordinator.selectedIndex == 1)
        #expect(!coordinator.appendGeneratedCandidates(
            ["F"],
            after: "候補"
        ))
    }

    @Test
    func beginningAnEmptyCandidateSetReportsNoVisibleCandidates() {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let hasCandidates = fixture.coordinator.beginCandidates(
            context: "候補なし",
            preferredCandidates: [String](),
            learnedCandidates: [String](),
            dictionaryCandidates: [String]()
        )

        #expect(!hasCandidates)
        #expect(!fixture.coordinator.hasCandidates)
    }

    @Test
    func exposesAtMostFourCandidatesForEveryInputSize() {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        for count in [1, 3, 4, 5, 16] {
            let candidates = (0..<count).map { "候補\($0)" }
            fixture.coordinator.beginCandidates(
                context: "件数\(count)",
                preferredCandidates: [],
                learnedCandidates: candidates,
                dictionaryCandidates: []
            )

            #expect(fixture.coordinator.candidates
                == Array(candidates.prefix(4)))
        }
    }

    @Test
    func selectedSequenceCandidateRetainsItsSourceTokens() {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let coordinator = fixture.coordinator
        for _ in 0..<3 {
            for token in ["実装", "に", "進んで"] {
                _ = coordinator.learnedCandidateModels(
                    after: token,
                    committedTokens: [token],
                    learningSource: .directInput,
                    predictionEnabled: true,
                    learningEnabled: true,
                    breakPreviousSequence: false,
                    limit: 16
                )
            }
            coordinator.breakSequence()
        }
        let learned = coordinator.learnedCandidateModels(
            after: "実装",
            committedTokens: ["実装"],
            learningSource: .directInput,
            predictionEnabled: true,
            learningEnabled: false,
            breakPreviousSequence: false,
            limit: 16
        )
        coordinator.beginCandidates(
            context: "実装",
            preferredCandidates: [],
            learnedCandidates: learned,
            dictionaryCandidates: []
        )
        guard let index = coordinator.candidates.firstIndex(of: "に進んで")
        else {
            Issue.record("に進んで is not a next-input candidate")
            return
        }

        _ = coordinator.select(index: index)

        #expect(coordinator.selectedSourceTokens == ["に", "進んで"])
    }

    @Test
    func learnedSequenceDeduplicatesDictionaryCandidateWithoutLosingTokens() {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let learned = NextInputCandidateMetadata.candidate(
            from: NextInputPrediction(
                text: "東京都中野区",
                sourceTokens: ["東京都", "中野区"],
                sourceReadings: ["toukyouto", "nakanoku"]
            )
        )

        fixture.coordinator.beginCandidates(
            context: "住所",
            preferredCandidates: [],
            learnedCandidates: [learned],
            dictionaryCandidates: [Candidate(
                storageText: "東京都中野区",
                source: .userDictionary
            )]
        )
        _ = fixture.coordinator.select(index: 0)

        #expect(fixture.coordinator.candidates == ["東京都中野区"])
        #expect(fixture.coordinator.selectedSourceTokens == ["東京都", "中野区"])
        #expect(fixture.coordinator.selectedSourceReadings
            == ["toukyouto", "nakanoku"])
    }

    @Test
    func separatelyCommittedSpaceBecomesPartOfThePreviousLearningUnit() {
        let fixture = makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            _ = fixture.coordinator.learnedCandidateModels(
                after: "Smart",
                committedTokens: [
                    NextInputLearningToken(text: "Smart", reading: "smart")
                ],
                learningSource: .directInput,
                predictionEnabled: true,
                learningEnabled: true,
                breakPreviousSequence: false,
                limit: 16
            )
            #expect(fixture.coordinator.appendSeparatorToLastInput(" "))
            _ = fixture.coordinator.learnedCandidateModels(
                after: "Inn",
                committedTokens: [
                    NextInputLearningToken(text: "Inn", reading: "inn")
                ],
                learningSource: .directInput,
                predictionEnabled: true,
                learningEnabled: true,
                breakPreviousSequence: false,
                limit: 16
            )
            fixture.coordinator.breakSequence()
        }

        #expect(fixture.coordinator.learnedCompoundPredictions(
            matchingPrefix: "smart",
            excluding: []
        ).first?.text == "Smart Inn")
    }

    private func makeFixture() -> (
        coordinator: NextInputCandidateCoordinator,
        directory: URL,
        fileURL: URL
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("next-input.json")
        return (
            NextInputCandidateCoordinator(
                predictionModel: NextInputPredictionModel(),
                writer: DeferredJSONFileWriter(
                    fileURL: fileURL,
                    delay: 60,
                    queueLabel: "myim.next-input-coordinator-test"
                )
            ),
            directory,
            fileURL
        )
    }
}
