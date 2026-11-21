import Testing
@testable import MyIMECore

@Suite
struct TimeInputStateTests {
    @Test
    func singleTimeKeepsBothHandlesAligned() throws {
        var state = TimeInputState(
            time: try #require(TimeSelectionState(hour: 13, minute: 2))
        )

        #expect(state.mode == .time)
        #expect(state.minutes(of: .upper) == 780)
        #expect(state.minutes(of: .lower) == 780)

        let moved = state.move(.upper, to: 795)
        #expect(moved)
        #expect(state.minutes(of: .upper) == 795)
        #expect(state.minutes(of: .lower) == 795)
        #expect(state.mode == .time)
    }

    @Test
    func lowerHandleEntersRangeOnlyAfterItsValueChanges() throws {
        var state = TimeInputState(
            time: try #require(TimeSelectionState(hour: 13, minute: 0))
        )

        let unchanged = state.move(.lower, to: 780)
        #expect(!unchanged)
        #expect(state.mode == .time)
        let moved = state.move(.lower, to: 785)
        #expect(moved)
        #expect(state.mode == .range)
        #expect(state.start == 780)
        #expect(state.end == 785)
    }

    @Test
    func movingUpperHandleAcrossLowerSwapsOnlyTheirRoles() throws {
        var state = TimeInputState(
            range: try #require(TimeRangeSelection(start: 780, end: 840))
        )

        #expect(state.role(of: .upper) == .start)
        let met = state.move(.upper, to: 840)
        #expect(met)
        #expect(state.role(of: .upper) == .start)
        #expect(state.rangeSelection == nil)

        let crossed = state.move(.upper, to: 845)
        #expect(crossed)
        #expect(state.minutes(of: .upper) == 845)
        #expect(state.minutes(of: .lower) == 840)
        #expect(state.role(of: .upper) == .end)
        #expect(state.role(of: .lower) == .start)
        #expect(state.rangeSelection == TimeRangeSelection(start: 840, end: 845))
    }

    @Test
    func movingLowerHandleAcrossUpperSwapsOnlyTheirRoles() throws {
        var state = TimeInputState(
            range: try #require(TimeRangeSelection(start: 780, end: 840))
        )

        let crossed = state.move(.lower, to: 775)
        #expect(crossed)
        #expect(state.minutes(of: .upper) == 780)
        #expect(state.minutes(of: .lower) == 775)
        #expect(state.role(of: .upper) == .end)
        #expect(state.role(of: .lower) == .start)
        #expect(state.rangeSelection == TimeRangeSelection(start: 775, end: 780))
    }

    @Test
    func equalityKeepsRolesUntilAHandleActuallyCrosses() throws {
        var state = TimeInputState(
            range: try #require(TimeRangeSelection(start: 780, end: 840))
        )

        let met = state.move(.upper, to: 840)
        #expect(met)
        #expect(state.role(of: .upper) == .start)
        let returned = state.move(.upper, to: 835)
        #expect(returned)
        #expect(state.role(of: .upper) == .start)

        let crossed = state.move(.upper, to: 845)
        #expect(crossed)
        #expect(state.role(of: .upper) == .end)
        let returnedToEquality = state.move(.upper, to: 840)
        #expect(returnedToEquality)
        #expect(state.role(of: .upper) == .end)
    }

    @Test
    func escapeFromRangeKeepsTheCurrentChronologicalStart() throws {
        var state = TimeInputState(
            range: try #require(TimeRangeSelection(start: 780, end: 840))
        )
        let crossed = state.move(.upper, to: 900)
        #expect(crossed)
        #expect(state.start == 840)

        let returned = state.returnToTimeMode()
        #expect(returned)
        #expect(state.mode == .time)
        #expect(state.minutes(of: .upper) == 840)
        #expect(state.minutes(of: .lower) == 840)
        let unchanged = state.returnToTimeMode()
        #expect(!unchanged)
    }

    @Test
    func typedValuesMustUseFiveMinuteStepsButMayCross() throws {
        var state = TimeInputState(
            range: try #require(TimeRangeSelection(start: 780, end: 840))
        )

        let refused = state.set(.upper, to: 787)
        let accepted = state.set(.upper, to: 900)
        #expect(!refused)
        #expect(accepted)
        #expect(state.start == 840)
        #expect(state.end == 900)
    }
}
