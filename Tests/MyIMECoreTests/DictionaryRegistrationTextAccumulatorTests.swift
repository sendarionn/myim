import Testing
@testable import MyIMECore

@Suite
struct DictionaryRegistrationTextAccumulatorTests {
    @Test
    func movesPendingPasteBeforeFollowingInput() {
        #expect(DictionaryRegistrationTextAccumulator.confirmedText(
            confirmed: "前",
            pendingPaste: "貼付"
        ) == "前貼付")
    }

    @Test
    func keepsPendingPasteWithoutExistingText() {
        #expect(DictionaryRegistrationTextAccumulator.confirmedText(
            confirmed: nil,
            pendingPaste: "貼付"
        ) == "貼付")
    }

    @Test
    func leavesEmptyRegistrationUnset() {
        #expect(DictionaryRegistrationTextAccumulator.confirmedText(
            confirmed: nil,
            pendingPaste: nil
        ) == nil)
    }
}
