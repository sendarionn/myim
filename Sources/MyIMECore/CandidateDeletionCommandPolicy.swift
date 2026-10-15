public enum CandidateDeletionTarget: Equatable, Sendable {
    case standardCandidate
    case fuzzyCandidate
    case nextInputCandidate
    case recentEmoji
}

public enum CandidateDeletionCommandPolicy {
    public static func target(
        hasInput: Bool,
        hasStandardSelection: Bool,
        hasFuzzySelection: Bool,
        hasNextInputSelection: Bool,
        hasRecentEmojiSelection: Bool = false
    ) -> CandidateDeletionTarget? {
        // The emoji panel takes the keys while it is open, so its selection
        // is the one being looked at
        if hasRecentEmojiSelection {
            return .recentEmoji
        }
        if !hasInput {
            return hasNextInputSelection ? .nextInputCandidate : nil
        }
        if hasFuzzySelection {
            return .fuzzyCandidate
        }
        return hasStandardSelection ? .standardCandidate : nil
    }
}
