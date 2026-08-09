import Testing
@testable import MyIMECore

@Suite
struct InputBufferDeletionTests {
    @Test
    func deletesOneCharacter() {
        #expect(InputBufferDeletion.deletingBackward(
            from: "nihongo",
            unit: .character
        ) == "nihong")
    }

    @Test
    func deletesLastWordAndTrailingSeparators() {
        #expect(InputBufferDeletion.deletingBackward(
            from: "nihongo,test-input",
            unit: .word
        ) == "nihongo,")
    }

    @Test
    func deletesContinuousRomanInputAsOneWord() {
        #expect(InputBufferDeletion.deletingBackward(
            from: "tatemonowosekkeisuruhito",
            unit: .word
        ).isEmpty)
    }

    @Test
    func deletesEntireInput() {
        #expect(InputBufferDeletion.deletingBackward(
            from: "nihongo,test",
            unit: .all
        ).isEmpty)
    }
}
