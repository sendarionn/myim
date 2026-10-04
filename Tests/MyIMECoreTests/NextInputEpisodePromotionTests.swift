import Foundation
import Testing
@testable import MyIMECore

/// Selecting the same run of suggestions twice combines it into one
/// candidate, and every eligible candidate is ordered by its last use
@Suite
struct NextInputEpisodePromotionTests {
    @Test
    func oneSelectionEpisodeIsNotCombined() {
        var model = NextInputPredictionModel()
        selectEpisode(in: &model)
        model.record("実装")

        #expect(!model.candidates(after: "実装", limit: 16).contains("に進んで"))
    }

    @Test
    func twoSelectionEpisodesAreCombined() {
        var model = NextInputPredictionModel()
        selectEpisode(in: &model)
        selectEpisode(in: &model)
        model.record("実装")

        let prediction = model.predictions(after: "実装", limit: 16).first {
            $0.text == "に進んで"
        }
        #expect(prediction?.sourceTokens == ["に", "進んで"])
    }

    @Test
    func selectingTheCombinedCandidateOnlyRefreshesItsRecency() throws {
        var model = NextInputPredictionModel()
        selectEpisode(in: &model)
        selectEpisode(in: &model)
        model.record("実装")
        model.record("を")
        model.breakSequence()
        for _ in 0..<5 {
            model.record("実装")
            model.record(tokens: ["に", "進んで"], source: .acceptedSuggestion)
            model.breakSequence()
        }

        #expect(try episodeCount(of: ["に", "進んで"], after: ["実装"], in: model)
            == 2)
        #expect(model.candidates(after: "実装", limit: 16).first == "に進んで")
    }

    @Test
    func singleAndCombinedCandidatesFollowTheSameRecencyOrder() {
        var model = eligibleCandidatesAfterImplementation()
        use("に", in: &model)
        use(["に", "進んで"], in: &model)
        use("を", in: &model)

        #expect(model.candidates(after: "実装", limit: 16)
            == ["を", "に進んで", "に"])
    }

    @Test
    func lastUsedCombinedCandidateComesFirst() {
        var model = eligibleCandidatesAfterImplementation()
        use("に", in: &model)
        use("を", in: &model)
        use(["に", "進んで"], in: &model)

        #expect(model.candidates(after: "実装", limit: 16)
            == ["に進んで", "を", "に"])
    }

    @Test
    func recentUseInAnotherContextDoesNotReorderThisContext() {
        var model = NextInputPredictionModel()
        for follower in ["を", "に"] {
            model.record("実装")
            model.record(follower)
            model.breakSequence()
        }
        model.record("確認")
        model.record("を")
        model.breakSequence()

        #expect(model.candidates(after: "実装", limit: 16) == ["に", "を"])
    }

    @Test
    func candidateFromSeveralMatchingContextsAppearsOnce() {
        var model = NextInputPredictionModel()
        for _ in 0..<3 {
            model.record(tokens: ["修正", "の", "実装"])
            model.breakSequence()
        }
        model.record(tokens: ["確認", "の", "結果"])
        model.breakSequence()

        let candidates = model.candidates(after: ["修正", "の"], limit: 16)

        #expect(candidates == ["結果", "実装"])
    }

    @Test
    func episodesFromTwoControllersCombineInTheSharedStore() {
        let store = Self.store()
        let vscode = NextInputSuggestionCoordinator(store: store)
        let chrome = NextInputSuggestionCoordinator(store: store)

        selectEpisode(in: vscode)
        #expect(!learn("実装", source: .directInput, in: chrome)
            .contains("に進んで"))
        _ = learn("に", source: .acceptedSuggestion, in: chrome)
        _ = learn("進んで", source: .acceptedSuggestion, in: chrome)

        #expect(learn("実装", source: .directInput, in: vscode)
            .contains("に進んで"))
    }

    @Test
    func controllersDoNotJoinTheirSelectionsIntoOneEpisode() {
        let store = Self.store()
        let vscode = NextInputSuggestionCoordinator(store: store)
        let chrome = NextInputSuggestionCoordinator(store: store)

        for _ in 0..<2 {
            _ = learn("実装", source: .directInput, in: vscode)
            _ = learn("に", source: .acceptedSuggestion, in: chrome)
            _ = learn("進んで", source: .acceptedSuggestion, in: chrome)
        }

        #expect(!store.snapshot.candidates(after: "実装", limit: 16)
            .contains("に進んで"))
    }

    /// に, に進んで and を are all offered after 実装
    private func eligibleCandidatesAfterImplementation()
        -> NextInputPredictionModel {
        var model = NextInputPredictionModel()
        selectEpisode(in: &model)
        selectEpisode(in: &model)
        use("を", in: &model)
        return model
    }

    private func selectEpisode(in model: inout NextInputPredictionModel) {
        model.record("実装")
        model.record("に", source: .acceptedSuggestion)
        model.record("進んで", source: .acceptedSuggestion)
        model.breakSequence()
    }

    private func use(_ token: String, in model: inout NextInputPredictionModel) {
        use([token], in: &model)
    }

    private func use(
        _ tokens: [String],
        in model: inout NextInputPredictionModel
    ) {
        model.record("実装")
        model.record(tokens: tokens, source: .acceptedSuggestion)
        model.breakSequence()
    }

    private func selectEpisode(in coordinator: NextInputSuggestionCoordinator) {
        _ = learn("実装", source: .directInput, in: coordinator)
        _ = learn("に", source: .acceptedSuggestion, in: coordinator)
        _ = learn("進んで", source: .acceptedSuggestion, in: coordinator)
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

    /// Reads the persisted episode count of `tokens` after `context`
    private func episodeCount(
        of tokens: [String],
        after context: [String],
        in model: NextInputPredictionModel
    ) throws -> Int? {
        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(model)
        ) as? [String: Any]
        let contexts = json?["sequenceContexts"] as? [String: Any]
        let stored = contexts?[Self.key(for: context)] as? [String: Any]
        let candidates = stored?["candidates"] as? [String: Any]
        let stat = candidates?[Self.key(for: tokens)] as? [String: Any]
        return stat?["acceptedSuggestionCount"] as? Int
    }

    private static func key(for tokens: [String]) -> String {
        tokens.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
    }

    private static func store() -> NextInputLearningStore {
        NextInputLearningStore(
            model: NextInputPredictionModel(),
            writer: DeferredJSONFileWriter(
                fileURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathComponent("next-input.json"),
                delay: 60,
                queueLabel: "myim.next-input-episode-test"
            )
        )
    }
}
