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

    @Test func hourDialUsesOuterAndInnerTwentyFourHourRings() throws {
        var state = try #require(TimeSelectionState(hour: 9, minute: 37))
        state.selectHour(atClockAngle: 300, ring: .outer)
        #expect(state.hour == 10)
        #expect(state.minute == 37)
        state.selectHour(atClockAngle: 300, ring: .inner)
        #expect(state.hour == 22)
        #expect(state.minute == 37)
        state.selectHour(atClockAngle: 0, ring: .outer)
        #expect(state.hour == 12)
        state.selectHour(atClockAngle: 0, ring: .inner)
        #expect(state.hour == 0)
    }

    @Test func minuteDialSelectionSnapsWithoutCarryingHour() throws {
        var state = try #require(TimeSelectionState(hour: 10, minute: 55))
        state.selectMinute(atClockAngle: 0)
        #expect(state.hour == 10)
        #expect(state.minute == 0)
        state.selectMinute(atClockAngle: 217)
        #expect(state.minute == 35)
    }

    @Test func innerRingDistinguishesTwentyThreeFromMidnight() throws {
        var state = try #require(TimeSelectionState(hour: 12, minute: 5))
        state.selectHour(atClockAngle: 330, ring: .inner)
        #expect(state.hour == 23)
        state.selectHour(atClockAngle: 0, ring: .inner)
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
