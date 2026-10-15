import Testing
@testable import MyIMECore

/// Delete edits the emoji search, and closes the panel only when the
/// search was already empty
@Suite
struct EmojiPanelDeletionTests {
    @Test
    func deleteOnAnEmptySearchClosesThePanel() {
        #expect(EmojiPanelDeletion.action(
            searchWasEmpty: true,
            isSearchConfirmed: false,
            isRepeat: false
        ) == .closePanel)
    }

    @Test
    func deleteWithSearchTextEditsTheSearch() {
        // Deleting the last character is decided from the search before it,
        // so it edits the search and returns to the initial emojis
        #expect(EmojiPanelDeletion.action(
            searchWasEmpty: false,
            isSearchConfirmed: false,
            isRepeat: false
        ) == .deleteSearchCharacter)
    }

    @Test
    func emptiedSearchClosesOnTheNextDelete() {
        let sequence = [false, false, true].map {
            EmojiPanelDeletion.action(
                searchWasEmpty: $0,
                isSearchConfirmed: false,
                isRepeat: false
            )
        }

        #expect(sequence
            == [.deleteSearchCharacter, .deleteSearchCharacter, .closePanel])
    }

    @Test
    func heldDeleteStopsAtTheEmptySearch() {
        #expect(EmojiPanelDeletion.action(
            searchWasEmpty: true,
            isSearchConfirmed: false,
            isRepeat: true
        ) == .ignore)
        #expect(EmojiPanelDeletion.action(
            searchWasEmpty: false,
            isSearchConfirmed: false,
            isRepeat: true
        ) == .deleteSearchCharacter)
    }

    @Test
    func confirmedSearchIsNotEdited() {
        #expect(EmojiPanelDeletion.action(
            searchWasEmpty: false,
            isSearchConfirmed: true,
            isRepeat: false
        ) == .ignore)
    }

    @Test(arguments: [
        ("deleteBackward:", InputBufferDeletionUnit.character),
        ("deleteBackwardByDecomposingPreviousCharacter:", .character),
        ("deleteWordBackward:", .word),
        ("deleteToBeginningOfLine:", .all)
    ])
    func deletionCommandsAreTakenByThePanel(
        selector: String,
        unit: InputBufferDeletionUnit
    ) {
        #expect(EmojiPanelDeletion.unit(forCommand: selector) == unit)
    }

    @Test(arguments: ["deleteForward:", "insertNewline:", "insertTab:"])
    func otherCommandsAreLeftAlone(_ selector: String) {
        #expect(EmojiPanelDeletion.unit(forCommand: selector) == nil)
    }
}
