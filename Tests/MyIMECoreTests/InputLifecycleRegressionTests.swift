import Testing
@testable import MyIMECore

@Suite
struct InputLifecycleRegressionTests {
    @Test
    func controllerAAsyncResultCannotMutateControllerBSession() throws {
        var tracker = InputLifecycleGenerationTracker()
        _ = tracker.recordActivation(for: "com.apple.TextEdit")
        var controllerA = InputSession()
        controllerA.activate(sessionGeneration: tracker.globalGeneration)
        controllerA.synchronize(input: "kou", cursorPosition: 3)
        let resultFromA = try #require(
            controllerA.snapshot(controllerID: "A")
        )

        _ = tracker.recordActivation(for: "com.apple.TextEdit")
        var controllerB = InputSession()
        controllerB.activate(sessionGeneration: tracker.globalGeneration)
        controllerB.synchronize(input: "kouho", cursorPosition: 5)

        #expect(!controllerB.accepts(
            resultFromA,
            controllerID: "B",
            isActive: true
        ))
    }

    @Test
    func asyncResultCannotApplyAfterInputRevisionChanges() throws {
        var session = InputSession()
        session.activate(sessionGeneration: 1)
        session.synchronize(input: "ko", cursorPosition: 2)
        let oldResult = try #require(session.snapshot(controllerID: "A"))

        session.synchronize(input: "kou", cursorPosition: 3)

        #expect(!session.accepts(
            oldResult,
            controllerID: "A",
            isActive: true
        ))
    }

    @Test
    func delayedPanelRequestCannotPresentAfterDeactivation() throws {
        var session = InputSession()
        session.activate(sessionGeneration: 1)
        session.synchronize(input: "kouho", cursorPosition: 5)
        let panelRequest = try #require(
            session.snapshot(controllerID: "A")
        )

        #expect(!session.accepts(
            panelRequest,
            controllerID: "A",
            isActive: false
        ))
    }

    @Test
    func delayedWillCloseFromControllerADoesNotCommitControllerB() {
        var tracker = InputLifecycleGenerationTracker()
        let applicationGenerationA = tracker.recordActivation(
            for: "com.microsoft.VSCode"
        )
        let globalGenerationA = tracker.globalGeneration
        _ = tracker.recordActivation(for: "com.microsoft.VSCode")

        let controllerAWasSuperseded = tracker.shouldRetireController(
            application: "com.microsoft.VSCode",
            applicationGeneration: applicationGenerationA,
            globalGeneration: globalGenerationA
        )

        #expect(controllerAWasSuperseded)
        #expect(!InputControllerClosurePolicy.shouldCommitComposition(
            deactivationWasPending: true,
            sessionWasSuperseded: controllerAWasSuperseded
        ))
    }
}
