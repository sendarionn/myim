import Testing
@testable import MyIMECore

@Suite
struct InputInteractionStateTests {
    @Test
    func resolvesInteractionState() {
        func resolve(
            hasInput: Bool = false,
            isRegistering: Bool = false,
            hasCandidate: Bool = false,
            hasFuzzySuggestion: Bool = false,
            hasNextInput: Bool = false
        ) -> InputInteractionState {
            InputInteractionState.resolve(
                hasInput: hasInput,
                isRegisteringDictionary: isRegistering,
                hasSelectedCandidate: hasCandidate,
                hasSelectedFuzzySuggestion: hasFuzzySuggestion,
                hasSelectedNextInput: hasNextInput
            )
        }

        #expect(resolve() == .idle)
        #expect(resolve(hasInput: true) == .composing)
        #expect(
            resolve(hasInput: true, hasCandidate: true)
                == .selectingCandidate
        )
        #expect(
            resolve(hasInput: true, hasFuzzySuggestion: true)
                == .selectingFuzzySuggestion
        )
        #expect(
            resolve(hasNextInput: true) == .selectingNextInput
        )
        #expect(
            resolve(
                hasInput: true,
                isRegistering: true,
                hasCandidate: true,
                hasFuzzySuggestion: true,
                hasNextInput: true
            ) == .registeringDictionary
        )
    }
}
