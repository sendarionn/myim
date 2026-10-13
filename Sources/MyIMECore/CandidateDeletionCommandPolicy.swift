public enum CandidateDeletionTarget: Equatable, Sendable {
    case standardCandidate
    case fuzzyCandidate
    case nextInputCandidate
}

public enum CandidateDeletionCommandPolicy {
    public static func target(
        hasInput: Bool,
        hasStandardSelection: Bool,
        hasFuzzySelection: Bool,
        hasNextInputSelection: Bool
    ) -> CandidateDeletionTarget? {
        if !hasInput {
            return hasNextInputSelection ? .nextInputCandidate : nil
        }
        if hasFuzzySelection {
            return .fuzzyCandidate
        }
        return hasStandardSelection ? .standardCandidate : nil
    }
}
