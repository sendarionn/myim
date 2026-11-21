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
        let state = TimeInputState(
            range: try #require(TimeRangeSelection(start: 780, end: 900))
        )
        let knobFraction = 780.0 / 1440

        let drag = TimeRangeFineDrag(
            handle: .upper,
            state: state,
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
        var state = TimeInputState(
            range: try #require(TimeRangeSelection(start: 780, end: 900))
        )
        var drag = TimeRangeFineDrag(
            handle: .upper,
            state: state,
            knobFraction: 0.5,
            cursorX: 100,
            railWidth: railWidth
        )

        drag.drag(toX: 100 + minute * 3, state: &state)
        #expect(state.start == 785)

        drag.drag(toX: 100 + minute * 2, state: &state)
        #expect(state.start == 780)
    }

    /// Movements below a selectable step add up instead of being lost
    @Test
    func smallMovementsAddUp() throws {
        var state = TimeInputState(
            range: try #require(TimeRangeSelection(start: 780, end: 900))
        )
        var drag = TimeRangeFineDrag(
            handle: .upper,
            state: state,
            knobFraction: 0.5,
            cursorX: 0,
            railWidth: railWidth
        )

        for step in 1...10 {
            drag.drag(toX: minute * 0.3 * Double(step), state: &state)
        }

        #expect(state.start == 785)
    }

    /// The fixed zoom window stays unchanged while a physical handle crosses
    /// the other one
    @Test
    func crossingSwapsRolesWithoutChangingTheHeldHandle() throws {
        var state = TimeInputState(
            range: try #require(TimeRangeSelection(start: 780, end: 790))
        )
        var drag = TimeRangeFineDrag(
            handle: .upper,
            state: state,
            knobFraction: 0.5,
            cursorX: 0,
            railWidth: railWidth
        )

        drag.drag(toX: minute * 30, state: &state)
        #expect(state.minutes(of: .upper) == 810)
        #expect(state.role(of: .upper) == .end)
        #expect(state.start == 790)
        #expect(state.end == 810)

        drag.drag(toX: minute * 25, state: &state)
        #expect(state.minutes(of: .upper) == 805)
        #expect(state.start == 790)
        #expect(state.end == 805)
    }

    @Test
    func stopsAtTheEdgeOfTheShownHour() throws {
        var state = TimeInputState(
            range: try #require(TimeRangeSelection(start: 780, end: 1200))
        )
        var drag = TimeRangeFineDrag(
            handle: .upper,
            state: state,
            knobFraction: 0.5,
            cursorX: 0,
            railWidth: railWidth
        )

        drag.drag(toX: minute * 45, state: &state)
        #expect(state.start == 810)

        drag.drag(toX: minute * 40, state: &state)
        #expect(state.start == 805)
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
        let state = TimeInputState(range: range)
        let handle: TimeInputState.Handle = minutes == 1440 ? .lower : .upper
        let drag = TimeRangeFineDrag(
            handle: handle,
            state: state,
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
        var state = TimeInputState(
            range: try #require(TimeRangeSelection(start: 780, end: 900))
        )
        var drag = TimeRangeFineDrag(
            handle: .lower,
            state: state,
            knobFraction: 900.0 / 1440,
            cursorX: 50,
            railWidth: railWidth
        )

        drag.drag(toX: 50, state: &state)

        #expect(state.rangeSelection == TimeRangeSelection(start: 780, end: 900))
    }
}
