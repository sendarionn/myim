import Testing
@testable import MyIMECore

@Suite
struct MeaningSearchPromptBuilderTests {
    @Test
    func requiresAnotherReturnAfterConfirmingCurrentInput() {
        #expect(MeaningInputReturnPolicy.action(
            hasCurrentInput: true,
            hasConfirmedDraft: false
        ) == .confirmCurrentInput)
        #expect(MeaningInputReturnPolicy.action(
            hasCurrentInput: false,
            hasConfirmedDraft: true
        ) == .search)
        #expect(MeaningInputReturnPolicy.action(
            hasCurrentInput: false,
            hasConfirmedDraft: false
        ) == .none)
    }

    @Test
    func rejectsEmptyDescription() {
        #expect(MeaningSearchPromptBuilder.prompt(for: "  \n") == nil)
    }

    @Test
    func includesDescriptionInSearchPrompt() throws {
        let prompt = try #require(MeaningSearchPromptBuilder.prompt(
            for: "良い結果を期待して待つこと"
        ))
        #expect(prompt.contains("良い結果を期待して待つこと"))
        #expect(prompt.contains("最大32個"))
        #expect(prompt.contains("国語辞典の見出し語"))
    }

    @Test
    func parsesUniquePlainCandidates() {
        #expect(MeaningSearchPromptBuilder.candidates(from: """
        1. 期待
        - 希望
        「期待」
        説明を待ち望む
        """) == ["期待", "希望", "説明を待ち望む"])
    }

    @Test
    func retainsEnoughModelCandidatesForDictionaryFiltering() {
        let response = (1...40).map { "候補\($0)" }.joined(separator: "\n")
        #expect(MeaningSearchPromptBuilder.candidates(from: response).count == 32)
    }

    @Test
    func retryPromptExcludesPreviouslyRejectedCandidates() throws {
        let prompt = try #require(MeaningSearchPromptBuilder.prompt(
            for: "深く恥じ入るさま",
            excluding: ["恥ずかしい", "深く反省する"]
        ))
        #expect(prompt.contains("別の見出し語"))
        #expect(prompt.contains("恥ずかしい、深く反省する"))
    }
}
