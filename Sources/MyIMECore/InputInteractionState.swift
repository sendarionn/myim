public enum InputInteractionState: Equatable, Sendable {
    case idle
    case composing
    case selectingCandidate
    case selectingFuzzySuggestion
    case selectingNextInput
    case registeringDictionary

    public static func resolve(
        hasInput: Bool,
        isRegisteringDictionary: Bool,
        hasSelectedCandidate: Bool,
        hasSelectedFuzzySuggestion: Bool,
        hasSelectedNextInput: Bool
    ) -> Self {
        if isRegisteringDictionary {
            return .registeringDictionary
        }
        if hasSelectedFuzzySuggestion {
            return .selectingFuzzySuggestion
        }
        if hasInput, hasSelectedCandidate {
            return .selectingCandidate
        }
        if !hasInput, hasSelectedNextInput {
            return .selectingNextInput
        }
        return hasInput ? .composing : .idle
    }
}
