import Testing
@testable import MyIMECore

@Suite
struct DictionaryRegistrationSessionTests {
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
    func createsDisplayNameCompletionWithoutChangingOutput() {
        var session = DictionaryRegistrationSession(
            originalInput: "tomato",
            reading: "tomato"
        )
        session.appendConfirmed("https://example.com/tomato")
        let started = session.beginDisplayName(
            output: session.confirmedCandidate ?? ""
        )
        session.appendConfirmed("トマトの画像")

        let completion = session.completionWhenInputIsEmpty()

        #expect(started)
        #expect(completion == DictionaryRegistrationCompletion(
            reading: "tomato",
            output: "https://example.com/tomato",
            display: "トマトの画像"
        ))
    }

    @Test
    func exposesTheCurrentRegistrationInputField() {
        var session = DictionaryRegistrationSession(
            originalInput: "gg",
            reading: "gg"
        )

        #expect(session.activeInputField == .insertedText)

        session.appendConfirmed("https://www.google.com/")
        _ = session.beginDisplayName(
            output: session.confirmedCandidate ?? ""
        )

        #expect(session.activeInputField == .displayText)
    }

    @Test
    func doesNotCompleteWhilePasteIsPending() {
        var session = DictionaryRegistrationSession(
            originalInput: "key",
            reading: "key"
        )
        session.replacePendingPaste(with: "value")

        #expect(session.completionWhenInputIsEmpty() == nil)
    }
}
