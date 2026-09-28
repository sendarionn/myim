import Testing
@testable import MyIMECore

@Suite struct InputSessionSnapshotTests {
    @Test func acceptsOnlyTheStartingSessionAndRevision() {
        let snapshot = InputSessionSnapshot(
            sessionGeneration: 12,
            inputRevision: 31
        )

        #expect(snapshot.isCurrent(
            sessionGeneration: 12,
            inputRevision: 31
        ))
        #expect(!snapshot.isCurrent(
            sessionGeneration: 13,
            inputRevision: 31
        ))
        #expect(!snapshot.isCurrent(
            sessionGeneration: 12,
            inputRevision: 32
        ))
    }
}
