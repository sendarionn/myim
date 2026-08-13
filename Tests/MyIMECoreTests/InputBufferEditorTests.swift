import Testing
@testable import MyIMECore

@Suite
struct InputBufferEditorTests {
    @Test
    func insertsAtCursor() {
        var editor = InputBufferEditor(value: "nion", cursor: 2)
        editor.insert("h")

        #expect(editor.value == "nihon")
        #expect(editor.cursor == 3)
    }

    @Test
    func movesWithinInputBounds() {
        var editor = InputBufferEditor(value: "nihon")

        let movedLeft = editor.move(by: -2)
        #expect(movedLeft)
        #expect(editor.cursor == 3)
        let movedToStart = editor.move(by: -10)
        #expect(movedToStart)
        #expect(editor.cursor == 0)
        let movedPastStart = editor.move(by: -1)
        #expect(!movedPastStart)
    }

    @Test
    func deletesBeforeCursorWithoutChangingSuffix() {
        var editor = InputBufferEditor(value: "nihhon", cursor: 4)
        editor.deleteBackward(unit: .character)

        #expect(editor.value == "nihon")
        #expect(editor.cursor == 3)
    }

    @Test
    func commandDeletionClearsEntireInputFromMiddle() {
        var editor = InputBufferEditor(value: "nihongo", cursor: 3)
        editor.deleteBackward(unit: .all)

        #expect(editor.value.isEmpty)
        #expect(editor.cursor == 0)
    }

    @Test
    func deletesJapaneseCharacterFromEnd() {
        var editor = InputBufferEditor(value: "翻訳する文章")
        editor.deleteBackward(unit: .character)

        #expect(editor.value == "翻訳する文")
        #expect(editor.cursor == 5)
    }
}
