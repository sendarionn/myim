import Testing
@testable import MyIMECore

@Suite
struct TimeRangeSelectionTests {
    @Test(arguments: [
        (13, 0, 13 * 60, 14 * 60),
        (23, 30, 23 * 60 + 30, 24 * 60)
    ])
    func endsAnHourAfterTheClockTimeOrAtMidnight(
        hour: Int,
        minute: Int,
        start: Int,
        end: Int
    ) throws {
        let range = TimeRangeSelection(
            startingAt: try #require(TimeSelectionState(hour: hour, minute: minute))
        )

        #expect(range.start == start)
        #expect(range.end == end)
    }

    @Test
    func initialTimeIsRoundedToTheNearestSelectableValue() throws {
        let ordinary = TimeRangeSelection(
            startingAt: try #require(TimeSelectionState(hour: 13, minute: 7))
        )
        let dayEnd = TimeRangeSelection(
            startingAt: try #require(TimeSelectionState(hour: 23, minute: 58))
        )

        #expect(ordinary.start == 785)
        #expect(dayEnd.start == 1435)
        #expect(dayEnd.end == 1440)
    }

    @Test
    func rangeRequiresAtLeastOneFiveMinuteStep() {
        #expect(TimeRangeSelection(start: 780, end: 780) == nil)
        #expect(TimeRangeSelection(start: 780, end: 781) == nil)
        #expect(TimeRangeSelection(start: 780, end: 785) != nil)
    }

    @Test
    func showsTimesAsTheClockDoes() {
        #expect(TimeRangeSelection.text(forMinutes: 545) == "09:05")
        #expect(TimeRangeSelection.text(forMinutes: 1440) == "24:00")
    }
}
