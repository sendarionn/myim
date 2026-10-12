public enum InputInteractionState: Equatable, Sendable {
    case idle
    case composing
    case selectingCandidate
    case selectingFuzzyCandidate
    case selectingNextInput
    case registeringDictionary

    public static func resolve(
        hasInput: Bool,
        isRegisteringDictionary: Bool,
        hasSelectedCandidate: Bool,
        hasSelectedFuzzyCandidate: Bool,
        hasSelectedNextInput: Bool
    ) -> Self {
        if isRegisteringDictionary {
            return .registeringDictionary
        }
        if hasSelectedFuzzyCandidate {
            return .selectingFuzzyCandidate
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
