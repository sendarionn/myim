import Foundation
import Testing
@testable import MyIMECore

@Suite("TimeSelectionStateTests")
struct TimeSelectionStateTests {
    private let layout = TimeDialLayout()

    @Test func validatesTheWholeTwentyFourHourRange() {
        #expect(TimeSelectionState(hour: 0, minute: 0) != nil)
        #expect(TimeSelectionState(hour: 10, minute: 37) != nil)
        #expect(TimeSelectionState(hour: 23, minute: 59) != nil)
        #expect(TimeSelectionState(hour: 24, minute: 0) == nil)
        #expect(TimeSelectionState(hour: 0, minute: 60) == nil)
    }

    @Test func eachStageShowsOnlyItsOwnChoices() {
        #expect([0, 1].map {
            layout.label(atDialStep: $0, stage: .period)
        } == ["AM", "PM"])
        #expect((0..<12).map {
            layout.label(atDialStep: $0, stage: .hour)
        } == ["12", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"])
        #expect((0..<12).map {
            layout.label(atDialStep: $0, stage: .minute)
        } == ["00", "05", "10", "15", "20", "25", "30", "35", "40", "45", "50", "55"])
    }

    @Test func compactLayoutKeepsReadableLabelsAndSeparatedHitAreas() {
        #expect(layout.panelWidth == 332)
        #expect(layout.panelHeight == 430)
        #expect(layout.dialRadius * 2 == 260)
        #expect(layout.labelFontSize >= 16)
        #expect(layout.periodFontSize >= 20)
        #expect(layout.headingFontSize >= 14)
        #expect(layout.innerHitRadius < layout.labelRadius)
        #expect(layout.labelRadius < layout.outerRadius)
    }

    @Test func oneRingSelectsHoursAndFiveMinuteValues() {
        for step in 0..<12 {
            let hour = layout.labelCenter(atDialStep: step, stage: .hour)
            #expect(layout.selection(
                atX: hour.x,
                y: hour.y,
                stage: .hour
            ) == .hour(step == 0 ? 12 : step))
            let minute = layout.labelCenter(atDialStep: step, stage: .minute)
            #expect(layout.selection(
                atX: minute.x,
                y: minute.y,
                stage: .minute
            ) == .minute(step * 5))
        }
        #expect(layout.selection(atX: 0, y: 48, stage: .period)
            == .period(.am))
        #expect(layout.selection(atX: 0, y: -48, stage: .period)
            == .period(.pm))
    }

    @Test func centreOnlyBelongsToTheSplitPeriodDial() {
        #expect(layout.selection(atX: 0, y: 0, stage: .period)
            == .period(.am))
        #expect(layout.selection(atX: 0, y: 0, stage: .hour) == nil)
        #expect(layout.selection(atX: 0, y: 0, stage: .minute) == nil)
        #expect(layout.selection(
            atX: 0,
            y: layout.outerRadius + 0.1,
            stage: .minute
        ) == nil)
    }

    @Test func stagedSelectionConvertsToTwentyFourHourTime() throws {
        let initial = try #require(TimeSelectionState(hour: 9, minute: 5))
        var flow = TimeInputFlow(time: initial)

        #expect(flow.select(.period(.pm)) == nil)
        #expect(flow.stage == .hour)
        #expect(flow.select(.hour(3)) == nil)
        #expect(flow.stage == .minute)
        #expect(flow.select(.minute(30))?.digitalText == "15:30")
    }

    @Test(arguments: [
        (TimePeriod.am, 3, "03:00"),
        (TimePeriod.pm, 3, "15:00"),
        (TimePeriod.am, 12, "00:00"),
        (TimePeriod.pm, 12, "12:00"),
        (TimePeriod.pm, 11, "23:55")
    ])
    func periodAndHourMapping(
        period: TimePeriod,
        hour: Int,
        expected: String
    ) throws {
        let initial = try #require(TimeSelectionState(hour: 0, minute: 0))
        var flow = TimeInputFlow(time: initial)
        _ = flow.select(.period(period))
        _ = flow.select(.hour(hour))
        let minute = expected.hasSuffix(":55") ? 55 : 0
        #expect(flow.select(.minute(minute))?.digitalText == expected)
    }

    @Test func escapeMovesBackOneStageAndKeepsTheTime() throws {
        let selected = try #require(TimeSelectionState(hour: 15, minute: 30))
        var flow = TimeInputFlow(time: selected, stage: .minute)

        let movedToHour = flow.moveBack()
        #expect(movedToHour)
        #expect(flow.stage == .hour)
        #expect(flow.time == selected)
        let movedToPeriod = flow.moveBack()
        #expect(movedToPeriod)
        #expect(flow.stage == .period)
        #expect(flow.time == selected)
        let movedBeforePeriod = flow.moveBack()
        #expect(!movedBeforePeriod)
    }

    @Test func invalidValuesDoNotAdvanceTheFlow() throws {
        let initial = try #require(TimeSelectionState(hour: 9, minute: 5))
        var flow = TimeInputFlow(time: initial)

        #expect(flow.select(.hour(3)) == nil)
        #expect(flow.stage == .period)
        #expect(flow.select(.period(.pm)) == nil)
        #expect(flow.select(.hour(0)) == nil)
        #expect(flow.stage == .hour)
        #expect(flow.select(.hour(3)) == nil)
        #expect(flow.select(.minute(3)) == nil)
        #expect(flow.stage == .minute)
        #expect(flow.time.digitalText == "15:05")
    }

    @Test func restartReturnsToPeriodAndKeepsTheTime() throws {
        let selected = try #require(TimeSelectionState(hour: 15, minute: 30))
        var flow = TimeInputFlow(time: selected, stage: .minute)

        flow.restart()

        #expect(flow.stage == .period)
        #expect(flow.time == selected)
    }

    @Test(arguments: [
        (14, 32, "14:30"),
        (14, 33, "14:35"),
        (23, 58, "00:00"),
        (0, 0, "00:00"),
        (9, 5, "09:05")
    ])
    func initialTimeRoundsToNearestFiveMinutes(
        hour: Int,
        minute: Int,
        expected: String
    ) throws {
        let state = try #require(TimeSelectionState(hour: hour, minute: minute))
        #expect(state.roundedToNearestFiveMinutes().digitalText == expected)
    }
}
