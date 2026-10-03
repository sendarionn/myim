import Foundation
import Testing
@testable import MyIMECore

@Suite
struct NextInputSuggestionCoordinatorTests {
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
        coordinator.beginSuggestions(
            context: "開く",
            preferredCandidates: ["」"],
            learnedCandidates: [],
            dictionaryCandidates: []
        )
        _ = coordinator.select(index: 0)
        try coordinator.suppressSelectedCandidate()

        coordinator.beginSuggestions(
            context: "開く",
            preferredCandidates: ["」"],
            learnedCandidates: [],
            dictionaryCandidates: ["」", "閉じる"]
        )
        #expect(coordinator.candidates == ["閉じる"])

        coordinator.beginSuggestions(
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
        coordinator.beginSuggestions(
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
        coordinator.beginSuggestions(
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

    private func makeFixture() -> (
        coordinator: NextInputSuggestionCoordinator,
        directory: URL,
        fileURL: URL
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("next-input.json")
        return (
            NextInputSuggestionCoordinator(
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
