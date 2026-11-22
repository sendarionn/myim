/// The mark at the right end of a candidate row, decided from what the
/// candidate is rather than from its text
public enum CandidateAccessory: Equatable, Sendable {
    case none
    /// The candidate inserts other text than it shows, marked ●
    case alternateCommit
    /// A bookmark, marked with the bookmark symbol
    case bookmark

    /// A bookmark's symbol takes the place of ●, so a row shows one mark
    public static func resolve(
        hasDistinctCommitText: Bool,
        isBookmark: Bool
    ) -> Self {
        if isBookmark { return .bookmark }
        return hasDistinctCommitText ? .alternateCommit : .none
    }
}
