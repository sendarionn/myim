import Testing
@testable import MyIMECore

@Suite struct EmojiPanelCommandTests {
    @Test func routesTabCommandsToForwardSelection() {
        #expect(EmojiPanelCommand(
            selectorName: "insertTab:"
        ) == .moveSelection(backward: false))
        #expect(EmojiPanelCommand(
            selectorName: "insertTabIgnoringFieldEditor:"
        ) == .moveSelection(backward: false))
    }

    @Test func routesBacktabCommandsToBackwardSelection() {
        #expect(EmojiPanelCommand(
            selectorName: "insertBacktab:"
        ) == .moveSelection(backward: true))
        #expect(EmojiPanelCommand(
            selectorName: "insertBacktabIgnoringFieldEditor:"
        ) == .moveSelection(backward: true))
    }

    @Test func leavesUnrelatedCommandsUnhandled() {
        #expect(EmojiPanelCommand(selectorName: "insertNewline:") == nil)
    }
}
