import Testing
@testable import MyIMECore

@Suite
struct SelectionRegistrationReturnTargetTests {
    @Test
    func returnsOnceToTheApplicationTheServiceWasCalledFrom() {
        var target = SelectionRegistrationReturnTarget()
        target.begin(
            candidateProcessIdentifiers: [501],
            ownProcessIdentifier: 900
        )

        #expect(target.takeAfterRegistration() == 501)
        #expect(target.takeAfterRegistration() == nil)
    }

    /// The service is already frontmost when called, as the log of a real
    /// registration from Chrome showed; the menu bar owner is the source
    @Test
    func skipsTheServiceItselfForTheNextCandidate() {
        var target = SelectionRegistrationReturnTarget()
        target.begin(
            candidateProcessIdentifiers: [900, 30165, 30165],
            ownProcessIdentifier: 900
        )

        #expect(target.takeAfterRegistration() == 30165)
    }

    @Test(arguments: [
        [Int32?](), [nil], [900], [0, -1], [nil, 900, nil]
    ])
    func skipsItselfAndUnknownApplications(candidates: [Int32?]) {
        var target = SelectionRegistrationReturnTarget()
        target.begin(
            candidateProcessIdentifiers: candidates,
            ownProcessIdentifier: 900
        )

        #expect(target.takeAfterRegistration() == nil)
    }

    /// A failed registration keeps the target for the retry; closing the
    /// window forgets it
    @Test
    func keepsTheTargetUntilSuccessOrClose() {
        var target = SelectionRegistrationReturnTarget()
        target.begin(
            candidateProcessIdentifiers: [501],
            ownProcessIdentifier: 900
        )
        #expect(target.processIdentifier == 501)

        target.clear()

        #expect(target.takeAfterRegistration() == nil)
    }

    /// Each call of the service replaces the earlier application
    @Test
    func laterRegistrationReturnsToItsOwnApplication() {
        var target = SelectionRegistrationReturnTarget()
        target.begin(
            candidateProcessIdentifiers: [501],
            ownProcessIdentifier: 900
        )
        target.begin(
            candidateProcessIdentifiers: [900, 777],
            ownProcessIdentifier: 900
        )

        #expect(target.takeAfterRegistration() == 777)
    }
}
