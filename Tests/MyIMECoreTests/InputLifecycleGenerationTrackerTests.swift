import Testing
@testable import MyIMECore

@Suite
struct InputLifecycleGenerationTrackerTests {
    @Test
    func invalidatesOlderControllerWhenSameApplicationReactivates() {
        var tracker = InputLifecycleGenerationTracker()
        let oldGeneration = tracker.recordActivation(for: "com.microsoft.VSCode")
        let oldGlobalGeneration = tracker.globalGeneration
        let newGeneration = tracker.recordActivation(for: "com.microsoft.VSCode")
        let newGlobalGeneration = tracker.globalGeneration

        #expect(!tracker.isCurrent(
            application: "com.microsoft.VSCode",
            generation: oldGeneration
        ))
        #expect(tracker.shouldRetireController(
            application: "com.microsoft.VSCode",
            generation: oldGeneration,
            globalGeneration: oldGlobalGeneration
        ))
        #expect(tracker.isCurrent(
            application: "com.microsoft.VSCode",
            generation: newGeneration
        ))
        #expect(!tracker.shouldRetireController(
            application: "com.microsoft.VSCode",
            generation: newGeneration,
            globalGeneration: newGlobalGeneration
        ))
    }

    @Test
    func activationInAnotherApplicationRetiresSourceController() {
        var tracker = InputLifecycleGenerationTracker()
        let sourceGeneration = tracker.recordActivation(
            for: "com.microsoft.VSCode"
        )
        let sourceGlobalGeneration = tracker.globalGeneration
        _ = tracker.recordActivation(for: "com.apple.TextEdit")

        #expect(tracker.isCurrent(
            application: "com.microsoft.VSCode",
            generation: sourceGeneration
        ))
        #expect(tracker.shouldRetireController(
            application: "com.microsoft.VSCode",
            generation: sourceGeneration,
            globalGeneration: sourceGlobalGeneration
        ))
    }

    @Test
    func auxiliaryApplicationDoesNotRetireSourceController() {
        var tracker = InputLifecycleGenerationTracker()
        let sourceGeneration = tracker.recordActivation(
            for: "com.microsoft.VSCode"
        )
        let sourceGlobalGeneration = tracker.globalGeneration
        _ = tracker.recordActivation(
            for: "io.github.sendarionn.myim.external-browser",
            supersedesOtherApplications: false
        )

        #expect(!tracker.shouldRetireController(
            application: "com.microsoft.VSCode",
            generation: sourceGeneration,
            globalGeneration: sourceGlobalGeneration
        ))
    }

    @Test
    func anonymousActivationRetiresPreviousController() {
        var tracker = InputLifecycleGenerationTracker()
        _ = tracker.recordActivation(for: "com.microsoft.VSCode")
        let sourceGlobalGeneration = tracker.globalGeneration

        let anonymousGeneration = tracker.recordAnonymousActivation()

        #expect(tracker.shouldRetireController(
            globalGeneration: sourceGlobalGeneration
        ))
        #expect(!tracker.shouldRetireController(
            globalGeneration: anonymousGeneration
        ))
    }
}
