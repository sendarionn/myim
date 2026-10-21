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

    /// 1 to 12 on the inner ring and 13 to 24 on the outer ring
    @Test func hourDialUsesInnerAndOuterTwentyFourHourRings() throws {
        var state = try #require(TimeSelectionState(hour: 9, minute: 37))
        state.selectHour(atClockAngle: 300, ring: .inner)
        #expect(state.hour == 10)
        #expect(state.minute == 37)
        state.selectHour(atClockAngle: 300, ring: .outer)
        #expect(state.hour == 22)
        #expect(state.minute == 37)
        state.selectHour(atClockAngle: 0, ring: .inner)
        #expect(state.hour == 12)
        state.selectHour(atClockAngle: 0, ring: .outer)
        #expect(state.hour == 0)
        #expect(state.digitalText == "00:37")
    }

    @Test func dialLabelsShowTwentyFourForMidnight() {
        #expect((0..<12).map { TimeHourRing.inner.label(atDialStep: $0) }
            == ["12", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"])
        #expect((0..<12).map { TimeHourRing.outer.label(atDialStep: $0) }
            == ["24", "13", "14", "15", "16", "17", "18", "19", "20", "21",
                "22", "23"])
        #expect(TimeHourRing.outer.hour(atDialStep: 0) == 0)
        #expect(TimeHourRing.inner.hour(atDialStep: 0) == 12)
    }

    @Test(arguments: [
        (0, TimeHourRing.outer), (1, .inner), (12, .inner), (13, .outer),
        (23, .outer)
    ])
    func hourBelongsToItsRing(hour: Int, ring: TimeHourRing) {
        #expect(TimeHourRing(hour: hour) == ring)
    }

    @Test func minuteDialSelectionSnapsWithoutCarryingHour() throws {
        var state = try #require(TimeSelectionState(hour: 10, minute: 55))
        state.selectMinute(atClockAngle: 0)
        #expect(state.hour == 10)
        #expect(state.minute == 0)
        state.selectMinute(atClockAngle: 217)
        #expect(state.minute == 35)
    }

    @Test func outerRingDistinguishesTwentyThreeFromMidnight() throws {
        var state = try #require(TimeSelectionState(hour: 12, minute: 5))
        state.selectHour(atClockAngle: 330, ring: .outer)
        #expect(state.hour == 23)
        state.selectHour(atClockAngle: 0, ring: .outer)
        #expect(state.hour == 0)
    }

    @Test func overlappingHandsCanBeGrabbedAtTheirSeparateTips() throws {
        let layout = TimeDialLayout()
        let state = try #require(TimeSelectionState(hour: 0, minute: 0))
        #expect(TimeClockInteractionGeometry.dragTarget(
            x: 0, y: layout.hourHandLength, layout: layout, state: state
        ) == .hour)
        #expect(TimeClockInteractionGeometry.dragTarget(
            x: 0, y: layout.minuteHandLength, layout: layout, state: state
        ) == .minute)
        #expect(TimeClockInteractionGeometry.dragTarget(
            x: 40, y: 40, layout: layout, state: state
        ) == nil)
    }

    @Test func draggedHourKeepsItsRingNearTheBoundary() {
        let layout = TimeDialLayout()
        let boundary = (layout.innerLabelRadius + layout.outerLabelRadius) / 2

        #expect(layout.dragRing(
            atDistance: layout.outerLabelRadius, current: .inner
        ) == .outer)
        #expect(layout.dragRing(
            atDistance: layout.innerLabelRadius, current: .outer
        ) == .inner)
        #expect(layout.dragRing(atDistance: boundary, current: .inner) == .inner)
        #expect(layout.dragRing(atDistance: boundary, current: .outer) == .outer)
    }

    /// Labels share one size and keep their highlights apart on both rings
    @Test func labelsFitWithoutTouching() {
        let layout = TimeDialLayout()
        let innerSpacing = 2 * layout.innerLabelRadius * sin(.pi / 12)

        #expect(innerSpacing > layout.labelRadius * 2)
        #expect(layout.ringSpacing > layout.labelRadius * 2)
        #expect(layout.outerLabelRadius + layout.labelRadius
            < layout.dialRadius)
        #expect(layout.hourHandLength
            < layout.innerLabelRadius - layout.labelRadius)
        #expect(layout.minuteHandLength
            < layout.outerLabelRadius - layout.labelRadius)
    }

    /// A click selects the ring of the label drawn under it, and nothing
    /// between or beyond the rings
    @Test func labelClicksMatchWhereLabelsAreDrawn() {
        let layout = TimeDialLayout()

        #expect(layout.labelRing(atDistance: layout.innerLabelRadius) == .inner)
        #expect(layout.labelRing(
            atDistance: layout.innerLabelRadius + layout.labelRadius
        ) == .inner)
        #expect(layout.labelRing(atDistance: layout.outerLabelRadius) == .outer)
        #expect(layout.labelRing(
            atDistance: layout.outerLabelRadius - layout.labelRadius
        ) == .outer)
        #expect(layout.labelRing(
            atDistance: (layout.innerLabelRadius + layout.outerLabelRadius) / 2
        ) == nil)
        #expect(layout.labelRing(atDistance: 20) == nil)
        #expect(layout.labelRing(atDistance: layout.dialRadius) == nil)
    }
}
