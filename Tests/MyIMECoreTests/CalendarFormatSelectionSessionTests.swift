import Testing
@testable import MyIMECore

@Suite
struct CalendarFormatSelectionSessionTests {
    @Test
    func ownsTheWholeLogicalCalendarSelectionLifecycle() {
        var session = CalendarFormatSelectionSession()

        session.beginCalendarSelection()
        #expect(session.isActive)
        #expect(!session.isSelectingFormat)

        session.beginFormatLoading()
        #expect(session.isSelectingFormat)
        #expect(session.candidates == [])

        session.replaceCandidates(["10月3日", "2026-10-03"])
        #expect(session.selectedIndex == nil)
        #expect(session.moveSelection(by: 1) == 0)
        #expect(session.selectedCandidate == "10月3日")

        session.reset()
        #expect(!session.isActive)
        #expect(!session.isSelectingFormat)
        #expect(session.selectedCandidate == nil)
    }

    @Test
    func wrapsSelectionAndCalculatesTheVisiblePage() {
        var session = CalendarFormatSelectionSession()
        session.beginCalendarSelection()
        session.beginFormatLoading()
        session.replaceCandidates((0..<9).map(String.init))

        session.select(index: 7)

        #expect(session.pageRange(pageSize: 4) == 4..<8)
        #expect(session.moveSelection(by: 1) == 8)
        #expect(session.pageRange(pageSize: 4) == 8..<9)
        #expect(session.moveSelection(by: 1) == 0)
    }

    @Test
    func ignoresSelectionsOutsideTheCandidateRange() {
        var session = CalendarFormatSelectionSession()
        session.beginCalendarSelection()
        session.beginFormatLoading()
        session.replaceCandidates(["候補"])

        session.select(index: 0)
        session.select(index: 4)

        #expect(session.selectedIndex == 0)
        #expect(session.selectedCandidate == "候補")
    }
}
