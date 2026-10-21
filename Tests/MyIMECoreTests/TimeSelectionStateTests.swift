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
        let state = try #require(TimeSelectionState(hour: 0, minute: 0))
        #expect(TimeClockInteractionGeometry.dragTarget(
            x: 0, y: 48, radius: 100, state: state
        ) == .hour)
        #expect(TimeClockInteractionGeometry.dragTarget(
            x: 0, y: 68, radius: 100, state: state
        ) == .minute)
        #expect(TimeClockInteractionGeometry.dragTarget(
            x: 40, y: 40, radius: 100, state: state
        ) == nil)
    }

    @Test func hourRingUsesSeparateBandsAndRetainsBoundaryChoice() {
        #expect(TimeClockInteractionGeometry.hourRing(
            distanceRatio: 0.80, current: .inner
        ) == .outer)
        #expect(TimeClockInteractionGeometry.hourRing(
            distanceRatio: 0.60, current: .outer
        ) == .inner)
        #expect(TimeClockInteractionGeometry.hourRing(
            distanceRatio: 0.70, current: .inner
        ) == .inner)
    }
}
