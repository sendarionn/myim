import Testing
@testable import MyIMECore

@Suite struct InputSessionSnapshotTests {
    @Test func acceptsOnlyTheStartingSessionAndRevision() {
        let snapshot = InputSessionSnapshot(
            controllerID: "A",
            sessionGeneration: 12,
            inputRevision: 31,
            input: "kouho",
            cursorPosition: 5
        )

        #expect(snapshot.isCurrent(
            controllerID: "A",
            sessionGeneration: 12,
            inputRevision: 31,
            input: "kouho",
            cursorPosition: 5
        ))
        #expect(!snapshot.isCurrent(
            controllerID: "A",
            sessionGeneration: 13,
            inputRevision: 31,
            input: "kouho",
            cursorPosition: 5
        ))
        #expect(!snapshot.isCurrent(
            controllerID: "A",
            sessionGeneration: 12,
            inputRevision: 32,
            input: "kouho",
            cursorPosition: 5
        ))
        #expect(!snapshot.isCurrent(
            controllerID: "B",
            sessionGeneration: 12,
            inputRevision: 31,
            input: "kouho",
            cursorPosition: 5
        ))
    }

    @Test func rejectsResultAfterInputChanges() throws {
        var session = InputSession()
        session.activate(sessionGeneration: 12)
        session.synchronize(input: "kou", cursorPosition: 3)
        let snapshot = try #require(session.snapshot(controllerID: "A"))

        session.synchronize(input: "kouho", cursorPosition: 5)

        #expect(!session.accepts(
            snapshot,
            controllerID: "A",
            isActive: true
        ))
    }

    @Test func rejectsResultFromPreviousController() throws {
        var session = InputSession()
        session.activate(sessionGeneration: 12)
        session.synchronize(input: "kouho", cursorPosition: 5)
        let snapshot = try #require(session.snapshot(controllerID: "A"))

        #expect(!session.accepts(
            snapshot,
            controllerID: "B",
            isActive: true
        ))
    }

    @Test func rejectsResultAfterDeactivation() throws {
        var session = InputSession()
        session.activate(sessionGeneration: 12)
        session.synchronize(input: "kouho", cursorPosition: 5)
        let snapshot = try #require(session.snapshot(controllerID: "A"))

        #expect(!session.accepts(
            snapshot,
            controllerID: "A",
            isActive: false
        ))
    }
}
