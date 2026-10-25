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

    @Test func periodArrowsSelectAnAbsolutePeriodUntilEnter() throws {
        let initial = try #require(TimeSelectionState(hour: 15, minute: 30))
        var flow = TimeInputFlow(time: initial)

        let movedLeft = flow.moveSelection(.left)
        #expect(movedLeft)
        #expect(flow.time.period == .am)
        let movedUp = flow.moveSelection(.up)
        #expect(!movedUp)
        #expect(flow.time.period == .am)
        let movedRight = flow.moveSelection(.right)
        #expect(movedRight)
        #expect(flow.time.period == .pm)
        let movedDown = flow.moveSelection(.down)
        #expect(!movedDown)
        #expect(flow.stage == .period)
        let confirmed = flow.confirmCurrentSelection()
        #expect(confirmed == nil)
        #expect(flow.stage == .hour)
    }

    @Test func everyHourPositionUsesUnambiguousArrowVectors() throws {
        for step in 0..<12 {
            for direction in TimeDialArrowDirection.allCases {
                let initialHour = step == 0 ? 0 : step
                var flow = TimeInputFlow(
                    time: try #require(TimeSelectionState(
                        hour: initialHour,
                        minute: 0
                    )),
                    stage: .hour
                )
                let expected = expectedAdjacentStep(
                    from: step,
                    direction: direction
                )

                let moved = flow.moveSelection(direction)
                #expect(moved == (expected != nil))
                #expect(flow.time.twelveHour == ((expected ?? step) == 0
                    ? 12
                    : expected ?? step))
                #expect(flow.stage == .hour)
            }
        }
    }

    @Test func everyMinutePositionUsesUnambiguousArrowVectors() throws {
        for step in 0..<12 {
            for direction in TimeDialArrowDirection.allCases {
                var flow = TimeInputFlow(
                    time: try #require(TimeSelectionState(
                        hour: 0,
                        minute: step * 5
                    )),
                    stage: .minute
                )
                let expected = expectedAdjacentStep(
                    from: step,
                    direction: direction
                )

                let moved = flow.moveSelection(direction)
                #expect(moved == (expected != nil))
                #expect(flow.time.minute == (expected ?? step) * 5)
                #expect(flow.stage == .minute)
            }
        }
    }

    @Test func enterAdvancesHourAndCompletesMinute() throws {
        let initial = try #require(TimeSelectionState(hour: 15, minute: 30))
        var flow = TimeInputFlow(time: initial, stage: .hour)

        let confirmedHour = flow.confirmCurrentSelection()
        #expect(confirmedHour == nil)
        #expect(flow.stage == .minute)
        let confirmedMinute = flow.confirmCurrentSelection()
        #expect(confirmedMinute == initial)
        #expect(flow.stage == .minute)
    }

    @Test(arguments: [
        (TimeDialArrowDirection.right, 0, TimeDialRotation.clockwise),
        (TimeDialArrowDirection.right, 4, TimeDialRotation.counterclockwise),
        (TimeDialArrowDirection.left, 4, TimeDialRotation.clockwise),
        (TimeDialArrowDirection.left, 0, TimeDialRotation.counterclockwise),
        (TimeDialArrowDirection.up, 7, TimeDialRotation.clockwise),
        (TimeDialArrowDirection.up, 1, TimeDialRotation.counterclockwise),
        (TimeDialArrowDirection.down, 1, TimeDialRotation.clockwise),
        (TimeDialArrowDirection.down, 7, TimeDialRotation.counterclockwise)
    ])
    func repeatedArrowKeepsItsRotationForAWholeLap(
        direction: TimeDialArrowDirection,
        start: Int,
        rotation: TimeDialRotation
    ) throws {
        var flow = TimeInputFlow(
            time: try #require(TimeSelectionState(
                hour: start == 0 ? 12 : start,
                minute: 0
            )),
            stage: .hour
        )
        var sequence = TimeDialArrowSequence()

        for offset in 0..<12 {
            let moved = flow.moveSelection(
                direction,
                sequence: &sequence,
                at: Double(offset) * 0.05
            )
            #expect(moved)
            let delta = rotation == .clockwise ? offset + 1 : -(offset + 1)
            let expected = (start + delta % 12 + 12) % 12
            #expect(flow.time.twelveHour == (expected == 0 ? 12 : expected))
            #expect(sequence.rotation == rotation)
        }
        #expect(flow.time.twelveHour == (start == 0 ? 12 : start))
    }

    @Test func repeatedArrowKeepsRotationForMinuteDial() throws {
        var flow = TimeInputFlow(
            time: try #require(TimeSelectionState(hour: 0, minute: 20)),
            stage: .minute
        )
        var sequence = TimeDialArrowSequence()

        for offset in 0..<12 {
            let moved = flow.moveSelection(
                .left,
                sequence: &sequence,
                at: Double(offset) * 0.05
            )
            #expect(moved)
            #expect(flow.time.minute == ((5 + offset) % 12) * 5)
            #expect(sequence.rotation == .clockwise)
        }
        #expect(flow.time.minute == 20)
    }

    @Test func sameArrowAfterOneSecondReevaluatesItsDirection() throws {
        var flow = TimeInputFlow(
            time: try #require(TimeSelectionState(hour: 4, minute: 0)),
            stage: .hour
        )
        var sequence = TimeDialArrowSequence()
        for offset in 0..<6 {
            _ = flow.moveSelection(
                .left,
                sequence: &sequence,
                at: Double(offset) * 0.1
            )
        }
        #expect(flow.time.twelveHour == 10)
        #expect(sequence.rotation == .clockwise)

        let moved = flow.moveSelection(
            .left,
            sequence: &sequence,
            at: 1.6
        )

        #expect(moved)
        #expect(flow.time.twelveHour == 9)
        #expect(sequence.rotation == .counterclockwise)
    }

    @Test func changingArrowReevaluatesItsDirection() throws {
        var flow = TimeInputFlow(
            time: try #require(TimeSelectionState(hour: 4, minute: 0)),
            stage: .hour
        )
        var sequence = TimeDialArrowSequence()
        _ = flow.moveSelection(.left, sequence: &sequence, at: 0)
        #expect(flow.time.twelveHour == 5)
        #expect(sequence.rotation == .clockwise)

        let moved = flow.moveSelection(.right, sequence: &sequence, at: 0.1)

        #expect(moved)
        #expect(flow.time.twelveHour == 4)
        #expect(sequence.lastArrowKey == .right)
        #expect(sequence.rotation == .counterclockwise)
    }

    @Test func invalidArrowClearsTheRetainedRotation() throws {
        var flow = TimeInputFlow(
            time: try #require(TimeSelectionState(hour: 4, minute: 0)),
            stage: .hour
        )
        var sequence = TimeDialArrowSequence()
        for offset in 0..<5 {
            _ = flow.moveSelection(
                .left,
                sequence: &sequence,
                at: Double(offset) * 0.1
            )
        }
        #expect(flow.time.twelveHour == 9)
        #expect(sequence.rotation == .clockwise)

        let moved = flow.moveSelection(
            .right,
            sequence: &sequence,
            at: 0.5
        )

        #expect(!moved)
        #expect(flow.time.twelveHour == 9)
        #expect(sequence.lastArrowKey == nil)
        #expect(sequence.rotation == nil)
        #expect(sequence.lastInputTime == nil)
    }

    @Test func sequenceResetPreventsReuseAcrossStages() throws {
        var flow = TimeInputFlow(
            time: try #require(TimeSelectionState(hour: 4, minute: 20)),
            stage: .hour
        )
        var sequence = TimeDialArrowSequence()
        _ = flow.moveSelection(.left, sequence: &sequence, at: 0)
        #expect(sequence.rotation == .clockwise)

        sequence.reset()
        let confirmed = flow.confirmCurrentSelection()
        #expect(confirmed == nil)
        #expect(flow.stage == .minute)
        let moved = flow.moveSelection(
            .left,
            sequence: &sequence,
            at: 0.1
        )

        #expect(moved)
        #expect(flow.time.minute == 25)
        #expect(sequence.rotation == .clockwise)
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

    private func expectedAdjacentStep(
        from step: Int,
        direction: TimeDialArrowDirection
    ) -> Int? {
        let delta: Int?
        switch (step, direction) {
        case (0, .right), (1...2, .right), (1...2, .down),
             (3, .down), (4...5, .down), (4...5, .left),
             (6, .left), (7...8, .left), (7...8, .up),
             (9, .up), (10...11, .up), (10...11, .right):
            delta = 1
        case (0, .left), (1...2, .left), (1...2, .up),
             (3, .up), (4...5, .up), (4...5, .right),
             (6, .right), (7...8, .right), (7...8, .down),
             (9, .down), (10...11, .down), (10...11, .left):
            delta = -1
        default:
            delta = nil
        }
        guard let delta else { return nil }
        return (step + delta + 12) % 12
    }
}
