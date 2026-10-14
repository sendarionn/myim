public struct SystemCompositionCommitPlan: Equatable, Sendable {
    public let committedText: String
    public let selectedCandidate: Candidate?
    public let unselectedInputLearningEntry: UnselectedInputLearningEntry?

    public init(
        committedText: String,
        selectedCandidate: Candidate?,
        unselectedInputLearningEntry: UnselectedInputLearningEntry?
    ) {
        self.committedText = committedText
        self.selectedCandidate = selectedCandidate
        self.unselectedInputLearningEntry = unselectedInputLearningEntry
    }

    public static func resolve(
        originalInput: String,
        selectedCandidate: Candidate?,
        conversionSuffix: String = "",
        compositionSuffix: String = ""
    ) -> Self {
        if let selectedCandidate {
            return Self(
                committedText: selectedCandidate.commitText
                    + conversionSuffix + compositionSuffix,
                selectedCandidate: selectedCandidate,
                unselectedInputLearningEntry: nil
            )
        }
        return Self(
            committedText: originalInput,
            selectedCandidate: nil,
            unselectedInputLearningEntry: UnselectedInputLearningPolicy.entry(
                originalInput: originalInput,
                hasSelectedCandidate: false
            )
        )
    }
}
