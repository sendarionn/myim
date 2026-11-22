import Testing
@testable import MyIMECore

@Suite
struct TextDeletionKeyTests {
    @Test
    func deletionKeysBreakTheSequence() {
        #expect(TextDeletionKey.matches(keyCode: 51, control: false))
        #expect(TextDeletionKey.matches(keyCode: 117, control: false))
        #expect(TextDeletionKey.matches(keyCode: 4, control: true))
        #expect(TextDeletionKey.matches(keyCode: 2, control: true))
    }

    @Test
    func typingTheSameLettersDoesNot() {
        #expect(!TextDeletionKey.matches(keyCode: 4, control: false))
        #expect(!TextDeletionKey.matches(keyCode: 2, control: false))
        #expect(!TextDeletionKey.matches(keyCode: 7, control: false))
    }
}
