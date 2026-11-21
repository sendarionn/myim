import Testing
@testable import MyIMECore

@Suite
struct TimeSelectionStateTests {
    @Test
    func validatesTheWholeTwentyFourHourRange() {
        #expect(TimeSelectionState(hour: 0, minute: 0) != nil)
        #expect(TimeSelectionState(hour: 10, minute: 37) != nil)
        #expect(TimeSelectionState(hour: 23, minute: 59) != nil)
        #expect(TimeSelectionState(hour: 24, minute: 0) == nil)
        #expect(TimeSelectionState(hour: 0, minute: 60) == nil)
    }

    @Test
    func formatsDigitalTimeWithLeadingZeroes() throws {
        let state = try #require(TimeSelectionState(hour: 9, minute: 5))

        #expect(state.digitalText == "09:05")
    }
}
