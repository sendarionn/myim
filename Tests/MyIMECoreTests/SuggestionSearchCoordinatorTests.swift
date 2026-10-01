import Testing
@testable import MyIMECore

@Suite
@MainActor
struct SuggestionSearchCoordinatorTests {
    @Test
    func appliesOnlyTheLatestResultForAQueryKind() async {
        let coordinator = SuggestionSearchCoordinator()
        var applied: [String] = []

        coordinator.start(
            .official,
            query: "old",
            operation: { "old" },
            validate: { true },
            apply: { applied.append($0) }
        )
        coordinator.start(
            .official,
            query: "current",
            operation: { "current" },
            validate: { true },
            apply: { applied.append($0) }
        )
        await waitForTasks()

        #expect(applied == ["current"])
        #expect(coordinator.query(for: .official) == "current")
    }

    @Test
    func rejectsAResultWhenCurrentInputValidationFails() async {
        let coordinator = SuggestionSearchCoordinator()
        var applied = false

        coordinator.start(
            .javaScriptExtensions,
            query: "old",
            operation: { ["candidate"] },
            validate: { false },
            apply: { _ in applied = true }
        )
        await waitForTasks()

        #expect(!applied)
    }

    @Test
    func cancellationPreventsResultApplication() async {
        let coordinator = SuggestionSearchCoordinator()
        var applied = false
        var cancelled = false

        coordinator.start(
            .translation,
            query: "候補",
            operation: {
                try await Task.sleep(for: .milliseconds(50))
                return "candidate"
            },
            validate: { true },
            apply: { _ in applied = true },
            onCancel: { cancelled = true }
        )
        coordinator.cancel(.translation)
        try? await Task.sleep(for: .milliseconds(80))

        #expect(!applied)
        #expect(cancelled)
    }

    @Test
    func canDiscardACompletedOneShotQuery() async {
        let coordinator = SuggestionSearchCoordinator()

        coordinator.start(
            .translation,
            query: "候補",
            operation: { "candidate" },
            validate: { true },
            apply: { _ in },
            retainQueryAfterCompletion: false
        )
        await waitForTasks()

        #expect(coordinator.query(for: .translation) == nil)
    }

    private func waitForTasks() async {
        for _ in 0..<4 {
            await Task.yield()
        }
    }
}
