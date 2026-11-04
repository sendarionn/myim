import Testing
@testable import MyIMECore

@Suite
struct PasswordInputSourceRecoveryStateTests {
    private let myIM = "io.github.sendarionn.inputmethod.myime.Japanese"
    private let abc = "com.apple.keylayout.ABC"
    private let app = "com.example.editor"

    @Test(arguments: [
        ("AXTextField", "AXSecureTextField"),
        ("AXTextArea", "AXSecureTextField")
    ])
    func classifiesSecureFields(role: String, subrole: String) {
        #expect(PasswordInputFocusClassifier.classify(
            role: role,
            subrole: subrole
        ) == .secureText)
    }

    @Test(arguments: ["AXTextField", "AXTextArea", "AXComboBox"])
    func classifiesOrdinaryEditableFields(role: String) {
        #expect(PasswordInputFocusClassifier.classify(
            role: role,
            subrole: nil
        ) == .ordinaryText)
    }

    @Test
    func treatsMissingAccessibilityAttributesAsUnavailable() {
        #expect(PasswordInputFocusClassifier.classify(
            role: nil,
            subrole: nil
        ) == .unavailable)
    }

    @Test
    func restoresAfterSecureFocusThenSystemSwitch() {
        var state = makeState()

        #expect(state.focusChanged(
            to: .secureText,
            applicationIdentifier: app,
            now: 1
        ) == nil)
        state.inputSourceChanged(
            to: abc,
            isTemporaryASCIIKeyboard: true,
            applicationIdentifier: app,
            now: 1.2
        )

        #expect(state.focusChanged(
            to: .ordinaryText,
            applicationIdentifier: app,
            now: 8
        ) == PasswordInputSourceRecoveryRequest(
            applicationIdentifier: app,
            temporaryInputSourceIdentifier: abc
        ))
    }

    @Test
    func restoresWhenSystemSwitchArrivesBeforeSecureFocus() {
        var state = makeState()

        state.inputSourceChanged(
            to: abc,
            isTemporaryASCIIKeyboard: true,
            applicationIdentifier: app,
            now: 1
        )
        #expect(state.focusChanged(
            to: .secureText,
            applicationIdentifier: app,
            now: 1.7
        ) == nil)

        #expect(state.focusChanged(
            to: .ordinaryText,
            applicationIdentifier: app,
            now: 20
        ) != nil)
    }

    @Test
    func doesNotRestoreWhenMyIMWasNotSelected() {
        var state = PasswordInputSourceRecoveryState(
            myIMInputSourceIdentifier: myIM,
            currentInputSourceIdentifier: abc,
            currentApplicationIdentifier: app
        )

        _ = state.focusChanged(
            to: .secureText,
            applicationIdentifier: app,
            now: 1
        )
        state.inputSourceChanged(
            to: abc,
            isTemporaryASCIIKeyboard: true,
            applicationIdentifier: app,
            now: 1.1
        )

        #expect(state.focusChanged(
            to: .ordinaryText,
            applicationIdentifier: app,
            now: 2
        ) == nil)
    }

    @Test
    func doesNotRestoreWithoutSecureFieldEvidence() {
        var state = makeState()

        state.inputSourceChanged(
            to: abc,
            isTemporaryASCIIKeyboard: true,
            applicationIdentifier: app,
            now: 1
        )

        #expect(state.focusChanged(
            to: .ordinaryText,
            applicationIdentifier: app,
            now: 1.5
        ) == nil)
    }

    @Test
    func rejectsEventsOutsideTheCorrelationWindow() {
        var state = makeState()

        _ = state.focusChanged(
            to: .secureText,
            applicationIdentifier: app,
            now: 1
        )
        state.inputSourceChanged(
            to: abc,
            isTemporaryASCIIKeyboard: true,
            applicationIdentifier: app,
            now: 2.1
        )

        #expect(state.focusChanged(
            to: .ordinaryText,
            applicationIdentifier: app,
            now: 3
        ) == nil)
    }

    @Test
    func manualInputSourceChangeCancelsRecovery() {
        var state = confirmedState()

        state.inputSourceChanged(
            to: "com.apple.keylayout.USInternational-PC",
            isTemporaryASCIIKeyboard: true,
            applicationIdentifier: app,
            now: 3
        )

        #expect(state.focusChanged(
            to: .ordinaryText,
            applicationIdentifier: app,
            now: 4
        ) == nil)
    }

    @Test
    func repeatedSourceNotificationKeepsRecovery() {
        var state = confirmedState()

        state.inputSourceChanged(
            to: abc,
            isTemporaryASCIIKeyboard: true,
            applicationIdentifier: app,
            now: 3
        )

        #expect(state.focusChanged(
            to: .ordinaryText,
            applicationIdentifier: app,
            now: 4
        ) != nil)
    }

    @Test
    func applicationChangeCancelsRecovery() {
        var state = confirmedState()

        state.applicationChanged(to: "com.example.other")
        #expect(state.focusChanged(
            to: .ordinaryText,
            applicationIdentifier: "com.example.other",
            now: 4
        ) == nil)
    }

    @Test(arguments: [
        PasswordInputFocusKind.other,
        PasswordInputFocusKind.unavailable
    ])
    func uncertainFocusCancelsRecovery(_ kind: PasswordInputFocusKind) {
        var state = confirmedState()

        #expect(state.focusChanged(
            to: kind,
            applicationIdentifier: app,
            now: 3
        ) == nil)
        #expect(state.focusChanged(
            to: .ordinaryText,
            applicationIdentifier: app,
            now: 4
        ) == nil)
    }

    private func makeState() -> PasswordInputSourceRecoveryState {
        PasswordInputSourceRecoveryState(
            myIMInputSourceIdentifier: myIM,
            currentInputSourceIdentifier: myIM,
            currentApplicationIdentifier: app
        )
    }

    private func confirmedState() -> PasswordInputSourceRecoveryState {
        var state = makeState()
        _ = state.focusChanged(
            to: .secureText,
            applicationIdentifier: app,
            now: 1
        )
        state.inputSourceChanged(
            to: abc,
            isTemporaryASCIIKeyboard: true,
            applicationIdentifier: app,
            now: 1.1
        )
        return state
    }

    /// Focus is watched only from the temporary switch until it is settled,
    /// so ordinary typing sends no Accessibility messages to the application
    @Test
    func awaitsFocusOnlyDuringATemporarySwitch() {
        var state = PasswordInputSourceRecoveryState(
            myIMInputSourceIdentifier: "myim",
            currentInputSourceIdentifier: "myim",
            currentApplicationIdentifier: "app"
        )
        #expect(!state.isAwaitingFocus)

        state.inputSourceChanged(
            to: "abc",
            isTemporaryASCIIKeyboard: true,
            applicationIdentifier: "app",
            now: 10
        )
        #expect(state.isAwaitingFocus)

        _ = state.focusChanged(
            to: .secureText,
            applicationIdentifier: "app",
            now: 10.1
        )
        #expect(state.isAwaitingFocus)

        let request = state.focusChanged(
            to: .ordinaryText,
            applicationIdentifier: "app",
            now: 20
        )
        #expect(request?.temporaryInputSourceIdentifier == "abc")
        #expect(!state.isAwaitingFocus)
    }

    @Test
    func stopsAwaitingFocusWhenTheApplicationChanges() {
        var state = PasswordInputSourceRecoveryState(
            myIMInputSourceIdentifier: "myim",
            currentInputSourceIdentifier: "myim",
            currentApplicationIdentifier: "app"
        )
        state.inputSourceChanged(
            to: "abc",
            isTemporaryASCIIKeyboard: true,
            applicationIdentifier: "app",
            now: 10
        )

        state.applicationChanged(to: "other")

        #expect(!state.isAwaitingFocus)
    }
}
