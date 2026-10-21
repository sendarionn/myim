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

    @Test func hourDialSelectionRetainsMinuteAndPeriod() throws {
        var morning = try #require(TimeSelectionState(hour: 9, minute: 37))
        morning.selectHour(atClockAngle: 300)
        #expect(morning.hour == 10)
        #expect(morning.minute == 37)

        var afternoon = try #require(TimeSelectionState(hour: 15, minute: 22))
        afternoon.selectHour(atClockAngle: 0)
        #expect(afternoon.hour == 12)
        #expect(afternoon.minute == 22)
    }

    @Test func minuteDialSelectionSnapsWithoutCarryingHour() throws {
        var state = try #require(TimeSelectionState(hour: 10, minute: 55))
        state.selectMinute(atClockAngle: 0)
        #expect(state.hour == 10)
        #expect(state.minute == 0)
        state.selectMinute(atClockAngle: 217)
        #expect(state.minute == 35)
    }

    @Test func amPmSwitchPreservesTheTwelveHourValue() throws {
        var midnight = try #require(TimeSelectionState(hour: 0, minute: 5))
        midnight.setPM(true)
        #expect(midnight.hour == 12)
        midnight.setPM(false)
        #expect(midnight.hour == 0)

        var afternoon = try #require(TimeSelectionState(hour: 23, minute: 5))
        afternoon.setPM(false)
        #expect(afternoon.hour == 11)
    }
}
