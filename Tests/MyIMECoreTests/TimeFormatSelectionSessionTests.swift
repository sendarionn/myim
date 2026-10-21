import Testing
@testable import MyIMECore

@Suite("TimeFormatSelectionSessionTests")
struct TimeFormatSelectionSessionTests {
    @Test func ownsTimeAndFormatSelectionLifecycle() {
        var session = TimeFormatSelectionSession()
        session.beginTimeSelection()
        #expect(session.isActive)
        #expect(!session.isSelectingFormat)

        session.beginFormatLoading()
        #expect(session.isSelectingFormat)
        session.replaceCandidates(["14:35", "14時35分"])
        session.moveSelection(by: 1)
        #expect(session.selectedIndex == 0)

        session.reset()
        #expect(!session.isActive)
        #expect(!session.isSelectingFormat)
    }
}
