import Testing
@testable import MyIMECore

@Suite
struct DictionaryRegistrationSessionTests {
    @Test
    func startsByEditingTheDisplayWithBothFieldsPresent() {
        let session = DictionaryRegistrationSession(
            originalInput: "gg",
            reading: "gg"
        )

        #expect(session.activeInputField == .displayText)
        #expect(session.displayText().isEmpty)
        #expect(session.insertedText().isEmpty)
    }

    @Test
    func insertedTextFollowsTheDisplayUntilEdited() {
        var session = DictionaryRegistrationSession(
            originalInput: "gg",
            reading: "gg"
        )

        session.appendConfirmed("G")
        #expect(session.insertedText(pending: "oogle") == "Google")

        session.appendConfirmed("oogle")

        #expect(session.displayText() == "Google")
        #expect(session.insertedText() == "Google")
        #expect(!session.isInsertedTextCustomized)
    }

    @Test
    func togglesBetweenDisplayAndInsertedText() {
        var session = DictionaryRegistrationSession(
            originalInput: "gg",
            reading: "gg"
        )
        session.appendConfirmed("Goo")

        session.toggleInputField(absorbing: "gle")

        #expect(session.activeInputField == .insertedText)
        #expect(session.confirmedCandidate == nil)
        #expect(session.visibleInsertedText().isEmpty)
        #expect(session.insertedText() == "Google")
        #expect(!session.isInsertedTextCustomized)

        session.toggleInputField(absorbing: nil)

        #expect(session.activeInputField == .displayText)
        #expect(session.confirmedCandidate == "Google")
        #expect(session.visibleInsertedText() == "Google")
    }

    @Test
    func startsTheInsertedFieldEmptyForImmediateTyping() {
        var session = DictionaryRegistrationSession(
            originalInput: "gg",
            reading: "gg"
        )
        session.appendConfirmed("Google")
        session.toggleInputField(absorbing: nil)

        #expect(session.visibleInsertedText(pending: "https") == "https")

        session.appendConfirmed("https://www.google.com/")

        #expect(session.insertedText() == "https://www.google.com/")
        #expect(session.displayText() == "Google")
    }

    @Test
    func followsTheDisplayAgainWhenTheInsertedTextIsCleared() {
        var session = DictionaryRegistrationSession(
            originalInput: "gg",
            reading: "gg"
        )
        session.appendConfirmed("Google")
        session.toggleInputField(absorbing: nil)
        session.appendConfirmed("URL")
        #expect(session.isInsertedTextCustomized)
        while session.deleteBackwardFromConfirmed(unit: .character) {}

        #expect(!session.isInsertedTextCustomized)

        session.toggleInputField(absorbing: nil)
        session.appendConfirmed("検索")

        #expect(session.insertedText() == "Google検索")
    }

    @Test
    func keepsAnEditedInsertedTextWhenTheDisplayChanges() {
        var session = DictionaryRegistrationSession(
            originalInput: "gg",
            reading: "gg"
        )
        session.appendConfirmed("Google")
        session.toggleInputField(absorbing: nil)
        session.replacePendingPaste(with: "https://www.google.com/")
        session.absorbPendingPaste()

        #expect(session.isInsertedTextCustomized)
        #expect(session.displayText() == "Google")
        #expect(session.insertedText() == "https://www.google.com/")

        session.toggleInputField(absorbing: nil)
        session.appendConfirmed("検索")

        #expect(session.displayText() == "Google検索")
        #expect(session.insertedText() == "https://www.google.com/")
        #expect(session.completionWhenInputIsEmpty()
            == DictionaryRegistrationCompletion(
                reading: "gg",
                output: "https://www.google.com/",
                display: "Google検索"
            ))
    }

    @Test
    func registersAnOrdinaryWordWithoutToggling() {
        var session = DictionaryRegistrationSession(
            originalInput: "shiru",
            reading: "shiru"
        )
        session.appendConfirmed("知る")

        #expect(session.completionWhenInputIsEmpty()
            == DictionaryRegistrationCompletion(
                reading: "shiru",
                output: "知る",
                display: nil
            ))
    }

    @Test
    func savesMatchingFieldsAsAnOrdinaryCandidate() {
        var session = DictionaryRegistrationSession(
            originalInput: "gg",
            reading: "gg"
        )
        session.appendConfirmed("Google")
        session.toggleInputField(absorbing: nil)
        session.appendConfirmed("Google")

        #expect(session.isInsertedTextCustomized)
        #expect(session.completionWhenInputIsEmpty()?.display == nil)
    }

    @Test
    func registersTheDisplayWhenTheInsertedFieldIsLeftEmpty() {
        var session = DictionaryRegistrationSession(
            originalInput: "gg",
            reading: "gg"
        )
        session.appendConfirmed("Google")
        session.toggleInputField(absorbing: nil)

        #expect(session.completionWhenInputIsEmpty()
            == DictionaryRegistrationCompletion(
                reading: "gg",
                output: "Google",
                display: nil
            ))
    }

    @Test
    func togglingAloneDoesNotDetachTheInsertedText() {
        var session = DictionaryRegistrationSession(
            originalInput: "gg",
            reading: "gg"
        )
        session.appendConfirmed("Goo")
        session.toggleInputField(absorbing: nil)
        session.toggleInputField(absorbing: nil)
        session.appendConfirmed("gle")

        #expect(session.insertedText() == "Google")
    }

    @Test
    func completesWithAPendingPasteInOneStep() {
        var session = DictionaryRegistrationSession(
            originalInput: "kke",
            reading: "kke"
        )
        session.appendConfirmed("KKEホームページ")
        session.toggleInputField(absorbing: nil)
        session.replacePendingPaste(with: "https://www.kke.co.jp/")

        #expect(session.completionAbsorbingPendingPaste()
            == DictionaryRegistrationCompletion(
                reading: "kke",
                output: "https://www.kke.co.jp/",
                display: "KKEホームページ"
            ))
    }

    @Test
    func keepsAnAbsorbedPasteWhenItCannotCompleteYet() {
        var session = DictionaryRegistrationSession(
            originalInput: "kke",
            reading: "kke"
        )
        session.toggleInputField(absorbing: nil)
        session.replacePendingPaste(with: "https://www.kke.co.jp/")

        #expect(session.completionAbsorbingPendingPaste() == nil)
        #expect(session.pastedCandidate == nil)
        #expect(session.confirmedCandidate == "https://www.kke.co.jp/")
    }

    @Test
    func accumulatesConfirmedTextAndPendingPasteInOrder() {
        var session = DictionaryRegistrationSession(
            originalInput: "rlj",
            reading: "rlj"
        )

        session.appendConfirmed("リモート")
        session.replacePendingPaste(with: "ロック")
        session.replacePendingPaste(with: "ジャパン")
        session.absorbPendingPaste()

        #expect(session.confirmedCandidate == "リモートロックジャパン")
        #expect(session.pastedCandidate == nil)
    }

    @Test
    func deletesOnlyFromConfirmedText() {
        var session = DictionaryRegistrationSession(
            originalInput: "test",
            reading: "test"
        )
        session.appendConfirmed("表示名")

        let deleted = session.deleteBackwardFromConfirmed(unit: .character)

        #expect(deleted)
        #expect(session.confirmedCandidate == "表示")
    }

    @Test
    func doesNotCompleteWhilePasteIsPendingOrTheDisplayIsEmpty() {
        var session = DictionaryRegistrationSession(
            originalInput: "key",
            reading: "key"
        )
        session.replacePendingPaste(with: "value")

        #expect(session.completionWhenInputIsEmpty() == nil)

        var emptyDisplay = DictionaryRegistrationSession(
            originalInput: "key",
            reading: "key"
        )
        emptyDisplay.toggleInputField(absorbing: nil)
        emptyDisplay.appendConfirmed("value")

        #expect(emptyDisplay.completionWhenInputIsEmpty() == nil)
    }
}
