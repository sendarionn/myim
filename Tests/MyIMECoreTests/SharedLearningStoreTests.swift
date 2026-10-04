import Foundation
import Testing
@testable import MyIMECore

/// Two InputControllers in the same process share learned knowledge while
/// keeping their own candidate sessions and typing context
@Suite(.serialized)
struct SharedLearningStoreTests {
    @Test
    func nextInputLearningFromTwoControllersIsNotLost() throws {
        let fixture = Fixture()
        defer { fixture.remove() }
        let vscode = NextInputSuggestionCoordinator(store: fixture.store)
        let chrome = NextInputSuggestionCoordinator(store: fixture.store)

        learnRepetitions(3, in: vscode)
        vscode.flush()
        learnRepetitions(9, in: chrome)
        chrome.flush()

        let reloaded = try JSONDecoder().decode(
            NextInputPredictionModel.self,
            from: Data(contentsOf: fixture.nextInputURL)
        )
        #expect(reloaded.candidates(after: "実装", limit: 16).contains("に進んで"))
    }

    @Test
    func alternatingControllersPromoteTheContinuationTogether() {
        let fixture = Fixture()
        defer { fixture.remove() }
        let vscode = NextInputSuggestionCoordinator(store: fixture.store)
        let chrome = NextInputSuggestionCoordinator(store: fixture.store)

        for round in 0..<12 {
            learnRepetitions(1, in: round.isMultiple(of: 2) ? vscode : chrome)
        }
        let afterTyping = learn("実装", source: .directInput, in: chrome)

        #expect(afterTyping.contains("に進んで"))
    }

    @Test
    func controllersKeepTheirOwnTypingContext() {
        let fixture = Fixture()
        defer { fixture.remove() }
        let vscode = NextInputSuggestionCoordinator(store: fixture.store)
        let chrome = NextInputSuggestionCoordinator(store: fixture.store)

        for _ in 0..<12 {
            _ = learn("実装", source: .directInput, in: vscode)
            _ = learn("に", source: .acceptedSuggestion, in: chrome)
            _ = learn("進んで", source: .acceptedSuggestion, in: chrome)
        }

        #expect(!fixture.store.snapshot.candidates(after: "実装", limit: 16)
            .contains("に進んで"))
    }

    @Test
    func controllersKeepTheirOwnCandidateSelection() {
        let fixture = Fixture()
        defer { fixture.remove() }
        let vscode = NextInputSuggestionCoordinator(store: fixture.store)
        let chrome = NextInputSuggestionCoordinator(store: fixture.store)
        vscode.beginSuggestions(
            context: "実装",
            preferredCandidates: ["に", "を"],
            learnedCandidates: [String](),
            dictionaryCandidates: [String]()
        )
        chrome.beginSuggestions(
            context: "確認",
            preferredCandidates: ["した"],
            learnedCandidates: [String](),
            dictionaryCandidates: [String]()
        )

        vscode.select(index: 1)

        #expect(vscode.selectedCandidate == "を")
        #expect(chrome.selectedCandidate == nil)
        #expect(chrome.candidates == ["した"])
    }

    @Test
    func suppressionFromOneControllerAppliesToTheOther() throws {
        let fixture = Fixture()
        defer { fixture.remove() }
        let vscode = NextInputSuggestionCoordinator(store: fixture.store)
        let chrome = NextInputSuggestionCoordinator(store: fixture.store)
        vscode.beginSuggestions(
            context: "実装",
            preferredCandidates: ["に"],
            learnedCandidates: [String](),
            dictionaryCandidates: [String]()
        )
        vscode.select(index: 0)

        try vscode.suppressSelectedCandidate()

        #expect(chrome.isSuppressed("に", after: "実装"))
    }

    @Test
    func candidateSelectionHistoryFromTwoControllersIsNotLost() throws {
        let fixture = Fixture()
        defer { fixture.remove() }
        let shared = fixture.historyStore
        let vscode = shared
        let chrome = shared

        vscode.record("候補", readings: ["kouho"])
        chrome.record("公募", readings: ["kouho"])
        shared.flush()

        let reloaded = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: Data(contentsOf: fixture.historyURL)
        )
        #expect(Set(reloaded.candidates(for: ["kouho"])) == ["候補", "公募"])
    }

    @Test
    func sharedStorePersistsSequencesCountsAndSuppression() throws {
        let fixture = Fixture()
        defer { fixture.remove() }
        let coordinator = NextInputSuggestionCoordinator(store: fixture.store)
        learnRepetitions(12, in: coordinator)
        try fixture.store.suppress("を", after: "実装")
        fixture.store.flush()

        let reloaded = try JSONDecoder().decode(
            NextInputPredictionModel.self,
            from: Data(contentsOf: fixture.nextInputURL)
        )

        #expect(reloaded.candidates(after: "実装", limit: 16).contains("に進んで"))
        #expect(reloaded.isSuppressed("を", after: "実装"))
    }

    private func learnRepetitions(
        _ count: Int,
        in coordinator: NextInputSuggestionCoordinator
    ) {
        for _ in 0..<count {
            _ = learn("実装", source: .directInput, in: coordinator)
            _ = learn("に", source: .acceptedSuggestion, in: coordinator)
            _ = learn("進んで", source: .acceptedSuggestion, in: coordinator)
        }
    }

    private func learn(
        _ token: String,
        source: NextInputLearningSource,
        in coordinator: NextInputSuggestionCoordinator
    ) -> [String] {
        coordinator.learnedCandidateModels(
            after: token,
            committedTokens: [token],
            learningSource: source,
            predictionEnabled: true,
            learningEnabled: true,
            breakPreviousSequence: false,
            limit: 16
        ).map(\.commitText)
    }

    /// One store per process, as InputController creates them
    private struct Fixture {
        let directory: URL
        let store: NextInputLearningStore
        let historyStore: CandidateSelectionHistoryStore

        var nextInputURL: URL {
            directory.appendingPathComponent("next-input-model.json")
        }

        var historyURL: URL {
            directory.appendingPathComponent("history.json")
        }

        init() {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            store = NextInputLearningStore(
                model: NextInputPredictionModel(),
                writer: DeferredJSONFileWriter(
                    fileURL: directory.appendingPathComponent("next-input-model.json"),
                    delay: 60,
                    queueLabel: "myim.shared-learning-test"
                )
            )
            historyStore = CandidateSelectionHistoryStore(
                history: CandidateSelectionHistory(),
                writer: DeferredJSONFileWriter(
                    fileURL: directory.appendingPathComponent("history.json"),
                    delay: 60,
                    queueLabel: "myim.shared-history-test"
                )
            )
        }

        func remove() {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
