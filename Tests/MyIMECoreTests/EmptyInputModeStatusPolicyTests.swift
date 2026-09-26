import Testing
@testable import MyIMECore

@Suite
struct EmptyInputModeStatusPolicyTests {
    @Test
    func showsOnlyForAnActiveEmptyIdleMode() {
        #expect(EmptyInputModeStatusPolicy.shouldShow(
            isModeActive: true,
            isInputEmpty: true
        ))
        #expect(!EmptyInputModeStatusPolicy.shouldShow(
            isModeActive: true,
            isInputEmpty: false
        ))
        #expect(!EmptyInputModeStatusPolicy.shouldShow(
            isModeActive: true,
            isInputEmpty: true,
            isBusy: true
        ))
        #expect(!EmptyInputModeStatusPolicy.shouldShow(
            isModeActive: true,
            isInputEmpty: true,
            hasPresentedResults: true
        ))
    }
}
