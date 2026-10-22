import Testing
@testable import MyIMECore

@Suite
struct SelectionRegistrationReturnTargetTests {
    @Test
    func returnsOnceToTheApplicationTheServiceWasCalledFrom() {
        var target = SelectionRegistrationReturnTarget()
        target.begin(frontmostProcessIdentifier: 501, ownProcessIdentifier: 900)

        #expect(target.takeAfterRegistration() == 501)
        #expect(target.takeAfterRegistration() == nil)
    }

    @Test(arguments: [Int32?.none, 900, 0, -1])
    func skipsItselfAndUnknownApplications(frontmost: Int32?) {
        var target = SelectionRegistrationReturnTarget()
        target.begin(
            frontmostProcessIdentifier: frontmost,
            ownProcessIdentifier: 900
        )

        #expect(target.takeAfterRegistration() == nil)
    }

    /// A failed registration keeps the target for the retry; closing the
    /// window forgets it
    @Test
    func keepsTheTargetUntilSuccessOrClose() {
        var target = SelectionRegistrationReturnTarget()
        target.begin(frontmostProcessIdentifier: 501, ownProcessIdentifier: 900)
        #expect(target.processIdentifier == 501)

        target.clear()

        #expect(target.takeAfterRegistration() == nil)
    }

    /// Each call of the service replaces the earlier application
    @Test
    func laterRegistrationReturnsToItsOwnApplication() {
        var target = SelectionRegistrationReturnTarget()
        target.begin(frontmostProcessIdentifier: 501, ownProcessIdentifier: 900)
        target.begin(frontmostProcessIdentifier: 777, ownProcessIdentifier: 900)

        #expect(target.takeAfterRegistration() == 777)
    }
}
