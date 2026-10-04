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
        isGeneratedParticle: Bool,
        selectedCandidate: Candidate? = nil
    ) -> Self {
        let wasExplicitlySelected = selectedCandidate.map {
            ($0.storageText == value || $0.commitText == value)
                && $0.hasSource(.particleComposition)
                && $0.hasAttribute(.generated)
        } ?? false
        let acceptsGeneratedParticle = !isGeneratedParticle
            || wasExplicitlySelected
        return Self(
            learnsInput: closingBracketTracker.shouldRecordCommittedInput(
                value,
                requested: acceptsGeneratedParticle
            ),
            updatesSuggestions: acceptsGeneratedParticle
        )
    }
}
