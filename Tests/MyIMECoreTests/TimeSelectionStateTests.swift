import Foundation
import Testing
@testable import MyIMECore

@Suite("TimeSelectionStateTests")
struct TimeSelectionStateTests {
    @Test func validatesTheWholeTwentyFourHourRange() {
        #expect(TimeSelectionState(hour: 0, minute: 0) != nil)
        #expect(TimeSelectionState(hour: 10, minute: 37) != nil)
        #expect(TimeSelectionState(hour: 23, minute: 59) != nil)
        #expect(TimeSelectionState(hour: 24, minute: 0) == nil)
        #expect(TimeSelectionState(hour: 0, minute: 60) == nil)
    }

    @Test func keyboardMinuteRemainsExactWhenHandsAreRead() throws {
        let state = try #require(TimeSelectionState(hour: 10, minute: 37))
        #expect(state.digitalText == "10:37")
        #expect(state.minuteHandAngle == 222)
        #expect(abs(state.hourHandAngle - 318.5) < 0.0001)
    }

    /// AM shows 1 to 12 and PM shows 13 to 24, 24 standing for 0 o'clock
    @Test func pagesShowTwelveLabelsEach() {
        #expect((0..<12).map { TimeDialPage.am.label(atDialStep: $0) }
            == ["12", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"])
        #expect((0..<12).map { TimeDialPage.pm.label(atDialStep: $0) }
            == ["24", "13", "14", "15", "16", "17", "18", "19", "20", "21",
                "22", "23"])
        #expect(TimeDialPage.am.hour(atDialStep: 0) == 12)
        #expect(TimeDialPage.pm.hour(atDialStep: 0) == 0)
    }

    @Test(arguments: [
        (0, TimeDialPage.pm), (1, .am), (11, .am), (12, .am), (13, .pm),
        (23, .pm)
    ])
    func hourIsShownOnItsPage(hour: Int, page: TimeDialPage) {
        #expect(TimeDialPage(hour: hour) == page)
    }

    @Test(arguments: [
        (9, TimeDialPage.am, 9), (0, .am, 12), (2, .pm, 14), (0, .pm, 0),
        (3, .am, 3)
    ])
    func clickedLabelSelectsItsHourAndKeepsTheMinute(
        step: Int,
        page: TimeDialPage,
        hour: Int
    ) throws {
        var state = try #require(TimeSelectionState(hour: 10, minute: 35))

        state.selectHour(atDialStep: step, page: page)

        #expect(state.hour == hour)
        #expect(state.minute == 35)
    }

    @Test func midnightLabelIsWrittenAsZero() throws {
        var state = try #require(TimeSelectionState(hour: 10, minute: 30))
        state.selectHour(atDialStep: 0, page: .pm)
        #expect(state.digitalText == "00:30")
    }

    @Test func draggedMinuteFollowsEachMinuteWithoutCarryingHour() throws {
        var state = try #require(TimeSelectionState(hour: 10, minute: 55))
        state.selectMinute(atClockAngle: 357)
        #expect(state.hour == 10)
        #expect(state.minute == 0)
        state.selectMinute(atClockAngle: 222)
        #expect(state.minute == 37)
        state.selectMinute(atClockAngle: 217)
        #expect(state.minute == 36)
        state.selectMinute(atClockAngle: 354)
        #expect(state.minute == 59)
        #expect(state.hour == 10)
    }

    /// Labels sit on one ring with highlights apart, inside the dial
    @Test func labelsFitWithoutTouching() {
        let layout = TimeDialLayout()
        let spacing = 2 * layout.labelRingRadius * sin(.pi / 12)

        #expect(spacing > layout.labelHitRadius * 2)
        #expect(layout.labelRingRadius + layout.labelHitRadius
            < layout.dialRadius)
        // The hand ends before the labels; where its grab area reaches a
        // label, the label is chosen first
        #expect(layout.minuteHandLength
            < layout.labelRingRadius - layout.labelHitRadius)
        #expect(layout.hourHandLength < layout.minuteHandLength)
    }

    /// A click selects the label drawn under it, around its text too
    @Test func labelClicksMatchWhereLabelsAreDrawn() {
        let layout = TimeDialLayout()
        for step in 0..<12 {
            let center = layout.labelCenter(atDialStep: step)
            #expect(layout.labelStep(atX: center.x, y: center.y) == step)
            #expect(layout.labelStep(
                atX: center.x + layout.labelHitRadius - 1,
                y: center.y
            ) == step)
        }
        #expect(layout.labelStep(atX: 0, y: 0) == nil)
        #expect(layout.labelStep(atX: 0, y: layout.dialRadius) == nil)
    }

    @Test func minuteHandIsGrabbedAlongItsLengthButNotOnLabels() throws {
        let layout = TimeDialLayout()
        let state = try #require(TimeSelectionState(hour: 3, minute: 0))

        #expect(layout.grabsMinuteHand(
            atX: 0, y: layout.minuteHandLength, state: state
        ))
        #expect(layout.grabsMinuteHand(
            atX: layout.minuteHandTolerance - 1,
            y: layout.minuteHandLength / 2,
            state: state
        ))
        // The 12 label sits beyond the hand's tip
        #expect(!layout.grabsMinuteHand(
            atX: 0, y: layout.labelRingRadius, state: state
        ))
        // The hour hand points at 3 and cannot be grabbed
        #expect(!layout.grabsMinuteHand(
            atX: layout.hourHandLength, y: 0, state: state
        ))
    }
}
