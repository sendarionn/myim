import Testing
@testable import MyIMECore

@Suite("TimeFormatSelectionSessionTests")
struct TimeFormatSelectionSessionTests {
    @Test func ownsTimeAndFormatSelectionLifecycle() throws {
        var session = TimeFormatSelectionSession()
        session.beginTimeSelection()
        #expect(session.isActive)
        #expect(!session.isSelectingFormat)

        let time = try #require(TimeSelectionState(hour: 14, minute: 35))
        session.beginFormatLoading(for: time)
        #expect(session.isSelectingFormat)
        session.replaceCandidates(["14:35", "14時35分"])
        session.moveSelection(by: 1)
        #expect(session.selectedIndex == 0)

        session.reset()
        #expect(!session.isActive)
        #expect(!session.isSelectingFormat)
    }

    /// Esc on the formats of 14:30 reopens the clock at 14:30, and the
    /// formats made next are for the time chosen then
    @Test func escapeReturnsToTheClockWithTheChosenTime() throws {
        var session = TimeFormatSelectionSession()
        session.beginTimeSelection()
        let first = try #require(TimeSelectionState(hour: 14, minute: 30))
        session.beginFormatLoading(for: first)
        session.replaceCandidates(["14:30", "14時30分", "14時半"])
        session.select(index: 2)

        #expect(session.returnToTimeSelection() == first)
        #expect(session.isActive)
        #expect(!session.isSelectingFormat)
        #expect(session.selectedIndex == nil)

        let second = try #require(TimeSelectionState(hour: 14, minute: 35))
        session.beginFormatLoading(for: second)
        #expect(session.accepts(formatsFor: second))
    }

    @Test func formatsRequestedBeforeGoingBackAreDiscarded() throws {
        var session = TimeFormatSelectionSession()
        session.beginTimeSelection()
        let first = try #require(TimeSelectionState(hour: 14, minute: 30))
        session.beginFormatLoading(for: first)

        // Esc while the formats still load
        _ = session.returnToTimeSelection()
        #expect(!session.accepts(formatsFor: first))

        let second = try #require(TimeSelectionState(hour: 9, minute: 5))
        session.beginFormatLoading(for: second)
        #expect(!session.accepts(formatsFor: first))
        #expect(session.accepts(formatsFor: second))
    }

    @Test func nothingToReturnToOnceTheInputEnds() throws {
        var session = TimeFormatSelectionSession()
        session.beginTimeSelection()
        session.beginFormatLoading(
            for: try #require(TimeSelectionState(hour: 0, minute: 30))
        )

        session.reset()

        #expect(session.returnToTimeSelection() == nil)
    }
}
