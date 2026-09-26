import Testing
@testable import MyIMECore

@Suite
struct InputLifecycleGenerationTrackerTests {
    @Test
    func invalidatesOlderControllerWhenSameApplicationReactivates() {
        var tracker = InputLifecycleGenerationTracker()
        let oldGeneration = tracker.recordActivation(for: "com.microsoft.VSCode")
        let newGeneration = tracker.recordActivation(for: "com.microsoft.VSCode")

        #expect(!tracker.isCurrent(
            application: "com.microsoft.VSCode",
            generation: oldGeneration
        ))
        #expect(tracker.shouldRetireController(
            application: "com.microsoft.VSCode",
            generation: oldGeneration
        ))
        #expect(tracker.isCurrent(
            application: "com.microsoft.VSCode",
            generation: newGeneration
        ))
        #expect(!tracker.shouldRetireController(
            application: "com.microsoft.VSCode",
            generation: newGeneration
        ))
    }

    @Test
    func activationInAnotherApplicationDoesNotInvalidateSourceApplication() {
        var tracker = InputLifecycleGenerationTracker()
        let sourceGeneration = tracker.recordActivation(
            for: "com.microsoft.VSCode"
        )
        _ = tracker.recordActivation(for: "com.apple.TextEdit")

        #expect(tracker.isCurrent(
            application: "com.microsoft.VSCode",
            generation: sourceGeneration
        ))
    }
}
