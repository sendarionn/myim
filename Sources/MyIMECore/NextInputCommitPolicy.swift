public struct NextInputCommitPolicy: Equatable, Sendable {
    public let learnsInput: Bool
    public let updatesSuggestions: Bool

    public init(learnsInput: Bool, updatesSuggestions: Bool) {
        self.learnsInput = learnsInput
        self.updatesSuggestions = updatesSuggestions
    }

    /// Resolve before the committed value is consumed by the tracker so
    /// a structural closing bracket is recognised as the pending closing
    public static func resolve(
        committing value: String,
        closingBracketTracker: ClosingBracketTracker,
        isGeneratedParticle: Bool
    ) -> Self {
        Self(
            learnsInput: closingBracketTracker.shouldRecordCommittedInput(
                value,
                requested: !isGeneratedParticle
            ),
            updatesSuggestions: !isGeneratedParticle
        )
    }
}
