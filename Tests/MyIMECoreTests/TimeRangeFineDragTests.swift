import Testing
@testable import MyIMECore

@Suite
struct TimeRangeFineDragTests {
    private let railWidth = 240.0
    /// One minute of cursor movement on the hour-wide rail
    private var minute: Double { railWidth / 60 }

    /// 13:00 sits 13/24 of the way along the day; the hour shown puts it at
    /// the same place, so neither the knob nor the time moves
    @Test
    func showsTheHourAroundTheKnobWhereItWas() throws {
        let range = try #require(TimeRangeSelection(start: 780, end: 900))
        let knobFraction = 780.0 / 1440

        let drag = TimeRangeFineDrag(
            edge: .start,
            range: range,
            knobFraction: knobFraction,
            cursorX: 100,
            railWidth: railWidth
        )

        #expect(drag.windowStart == 780 - 60 * knobFraction)
        #expect(abs(drag.fraction(forMinutes: 780) - knobFraction) < 1e-9)
        #expect(!drag.contains(minutes: 900))
    }

    @Test
    func movesInFiveMinuteStepsFromWhereTheCursorWas() throws {
        var range = try #require(TimeRangeSelection(start: 780, end: 900))
        var drag = TimeRangeFineDrag(
            edge: .start,
            range: range,
            knobFraction: 0.5,
            cursorX: 100,
            railWidth: railWidth
        )

        drag.drag(toX: 100 + minute * 3, range: &range)
        #expect(range.start == 785)

        drag.drag(toX: 100 + minute * 2, range: &range)
        #expect(range.start == 780)
    }

    /// Movements below a selectable step add up instead of being lost
    @Test
    func smallMovementsAddUp() throws {
        var range = try #require(TimeRangeSelection(start: 780, end: 900))
        var drag = TimeRangeFineDrag(
            edge: .start,
            range: range,
            knobFraction: 0.5,
            cursorX: 0,
            railWidth: railWidth
        )

        for step in 1...10 {
            drag.drag(toX: minute * 0.3 * Double(step), range: &range)
        }

        #expect(range.start == 785)
    }

    /// Past the other end the knob stops five minutes away, and turning back
    /// moves it at once
    @Test
    func stopsFiveMinutesBeforeTheOtherEndWithoutKeepingTheOvershoot() throws {
        var range = try #require(TimeRangeSelection(start: 780, end: 790))
        var drag = TimeRangeFineDrag(
            edge: .start,
            range: range,
            knobFraction: 0.5,
            cursorX: 0,
            railWidth: railWidth
        )

        drag.drag(toX: minute * 30, range: &range)
        #expect(range.start == 785)

        drag.drag(toX: minute * 25, range: &range)
        #expect(range.start == 780)
        #expect(range.end == 790)
    }

    @Test
    func stopsAtTheEdgeOfTheShownHour() throws {
        var range = try #require(TimeRangeSelection(start: 780, end: 1200))
        var drag = TimeRangeFineDrag(
            edge: .start,
            range: range,
            knobFraction: 0.5,
            cursorX: 0,
            railWidth: railWidth
        )

        drag.drag(toX: minute * 45, range: &range)
        #expect(range.start == 810)

        drag.drag(toX: minute * 40, range: &range)
        #expect(range.start == 805)
    }

    /// The knob's place on the whole day decides the hour shown, which
    /// therefore never runs before 0:00 or past 24:00
    @Test(arguments: [0, 5, 30, 720, 1380, 1435, 1440])
    func shownHourStaysWithinTheDay(minutes: Int) throws {
        let range = try #require(
            minutes == 1440
                ? TimeRangeSelection(start: 1435, end: 1440)
                : TimeRangeSelection(start: minutes, end: minutes + 5)
        )
        let edge: TimeRangeSelection.Edge = minutes == 1440 ? .end : .start
        let drag = TimeRangeFineDrag(
            edge: edge,
            range: range,
            knobFraction: Double(minutes) / 1440,
            cursorX: 0,
            railWidth: railWidth
        )

        #expect(drag.windowStart >= 0)
        #expect(drag.windowEnd <= 1440 + 1e-9)
    }

    /// Moving up or down alone changes nothing
    @Test
    func ignoresVerticalMovement() throws {
        var range = try #require(TimeRangeSelection(start: 780, end: 900))
        var drag = TimeRangeFineDrag(
            edge: .end,
            range: range,
            knobFraction: 900.0 / 1440,
            cursorX: 50,
            railWidth: railWidth
        )

        drag.drag(toX: 50, range: &range)

        #expect(range == TimeRangeSelection(start: 780, end: 900))
    }
}
