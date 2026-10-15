/// What Delete does while the emoji panel is open; the key never reaches
/// the app, so text before the composition is not deleted
public enum EmojiPanelDeletion: Equatable, Sendable {
    /// Delete on an empty search closes the panel
    case closePanel
    /// Delete edits the search, returning to the initial emojis when the
    /// last character goes
    case deleteSearchCharacter
    /// Delete does nothing but is still consumed
    case ignore

    /// Decided from the search before this Delete, so deleting the last
    /// character and deleting on an empty search stay separate
    public static func action(
        searchWasEmpty: Bool,
        isSearchConfirmed: Bool,
        isRepeat: Bool
    ) -> EmojiPanelDeletion {
        if searchWasEmpty {
            // Holding Delete past the last character does not close the
            // panel and then go on deleting the app's text
            return isRepeat ? .ignore : .closePanel
        }
        return isSearchConfirmed ? .ignore : .deleteSearchCharacter
    }

    /// The search text a Cocoa deletion command removes; some apps send
    /// these commands for Delete instead of the key event
    public static func unit(
        forCommand selectorName: String
    ) -> InputBufferDeletionUnit? {
        switch selectorName {
        case "deleteBackward:", "deleteBackwardByDecomposingPreviousCharacter:":
            .character
        case "deleteWordBackward:":
            .word
        case "deleteToBeginningOfLine:", "deleteToBeginningOfParagraph:":
            .all
        default:
            nil
        }
    }
}
