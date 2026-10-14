import Foundation

/// Next-input interaction of one input client
///
/// The candidate session and typing cursor belong to this client, while
/// learned knowledge lives in the shared `NextInputLearningStore`
public final class NextInputCandidateCoordinator {
    private let store: NextInputLearningStore
    private var cursor = NextInputSequenceCursor()
    private var session = NextInputCandidateSession()

    public init(store: NextInputLearningStore) {
        self.store = store
    }

    /// Creates a coordinator with its own store, for a single client
    public convenience init(
        predictionModel: NextInputPredictionModel,
        writer: DeferredJSONFileWriter<NextInputPredictionModel>
    ) {
        self.init(store: NextInputLearningStore(
            model: predictionModel,
            writer: writer
        ))
    }

    public var candidates: [String] {
        session.candidates
    }

    public var candidateModels: [Candidate] {
        session.candidateModels
    }

    public var hasCandidates: Bool {
        !session.candidates.isEmpty
    }

    public var selectedIndex: Int? {
        session.selectedIndex
    }

    public var selectedCandidate: String? {
        session.selectedCandidate
    }

    public var selectedCandidateModel: Candidate? {
        session.selectedCandidateModel
    }

    public var selectedSourceTokens: [String]? {
        guard let candidate = session.selectedCandidateModel else { return nil }
        return NextInputCandidateMetadata.sourceTokens(from: candidate)
    }

    public var selectedSourceReadings: [String?]? {
        guard let candidate = session.selectedCandidateModel else { return nil }
        return NextInputCandidateMetadata.sourceReadings(from: candidate)
    }

    public var context: String? {
        session.context
    }

    public func candidatesAfterLastInput(limit: Int) -> [String] {
        store.predictions(after: cursor, limit: limit).map(\.text)
    }

    public func learnedCandidates(
        after value: String,
        predictionEnabled: Bool,
        learningEnabled: Bool,
        breakPreviousSequence: Bool,
        limit: Int
    ) -> [String] {
        learnedCandidateModels(
            after: value,
            committedTokens: [value],
            learningSource: .directInput,
            predictionEnabled: predictionEnabled,
            learningEnabled: learningEnabled,
            breakPreviousSequence: breakPreviousSequence,
            limit: limit
        ).map(\.commitText)
    }

    public func learnedCandidateModels(
        after value: String,
        committedTokens: [String],
        learningSource: NextInputLearningSource,
        predictionEnabled: Bool,
        learningEnabled: Bool,
        breakPreviousSequence: Bool,
        limit: Int
    ) -> [Candidate] {
        guard predictionEnabled else { return [] }
        if breakPreviousSequence {
            breakSequence()
        }
        let predictions: [NextInputPrediction]
        if learningEnabled {
            store.record(
                tokens: committedTokens,
                source: learningSource,
                cursor: &cursor
            )
            predictions = store.predictions(after: cursor, limit: limit)
        } else {
            predictions = store.predictions(after: value, limit: limit)
        }
        return predictions.map(NextInputCandidateMetadata.candidate)
    }

    public func learnedCandidateModels(
        after value: String,
        committedTokens: [NextInputLearningToken],
        learningSource: NextInputLearningSource,
        predictionEnabled: Bool,
        learningEnabled: Bool,
        breakPreviousSequence: Bool,
        limit: Int
    ) -> [Candidate] {
        guard predictionEnabled else { return [] }
        if breakPreviousSequence {
            breakSequence()
        }
        let predictions: [NextInputPrediction]
        if learningEnabled {
            store.record(
                learningTokens: committedTokens,
                source: learningSource,
                cursor: &cursor
            )
            predictions = store.predictions(after: cursor, limit: limit)
        } else {
            predictions = store.predictions(after: value, limit: limit)
        }
        return predictions.map(NextInputCandidateMetadata.candidate)
    }

    public func learnedCompoundPredictions(
        matchingPrefix input: String,
        excluding visibleCandidates: Set<String>,
        limit: Int = NextInputPredictionModel.maximumLearnedCompoundCandidateCount
    ) -> [LearnedCompoundPrediction] {
        store.learnedCompoundPredictions(
            matchingPrefix: input,
            excluding: visibleCandidates,
            limit: limit
        )
    }

    @discardableResult
    public func appendSeparatorToLastInput(_ separator: String) -> Bool {
        cursor.appendSeparatorToLastInput(separator)
    }

    @discardableResult
    public func beginCandidates(
        context: String,
        preferredCandidates: [String],
        learnedCandidates: [String],
        dictionaryCandidates: [String],
        unsuppressibleCandidates: Set<String> = []
    ) -> Bool {
        beginCandidates(
            context: context,
            preferredCandidates: preferredCandidates.map {
                Candidate(storageText: $0, source: .nextInput)
            },
            learnedCandidates: learnedCandidates.map {
                Candidate(storageText: $0, source: .nextInput)
            },
            dictionaryCandidates: dictionaryCandidates.map {
                Candidate(storageText: $0, source: .nextInput)
            },
            unsuppressibleCandidates: unsuppressibleCandidates
        )
    }

    @discardableResult
    public func beginCandidates(
        context: String,
        preferredCandidates: [Candidate],
        learnedCandidates: [Candidate],
        dictionaryCandidates: [Candidate],
        unsuppressibleCandidates: Set<String> = []
    ) -> Bool {
        let visibleDictionaryCandidates = dictionaryCandidates.filter {
            !store.isSuppressed($0.commitText, after: context)
        }
        let visiblePreferredCandidates = preferredCandidates.filter {
            unsuppressibleCandidates.contains($0.commitText)
                || !store.isSuppressed($0.commitText, after: context)
        }
        let candidates = NextInputCandidateMerger.merged(
            preferred: visiblePreferredCandidates,
            learned: learnedCandidates + visibleDictionaryCandidates,
            limit: visiblePreferredCandidates.count
                + learnedCandidates.count
                + visibleDictionaryCandidates.count
        )
        session.begin(context: context, candidates: candidates)
        return !candidates.isEmpty
    }

    @discardableResult
    public func appendGeneratedCandidates(
        _ generated: [String],
        after context: String
    ) -> Bool {
        let visibleGenerated = generated.filter {
            !store.isSuppressed($0, after: context)
        }.map { Candidate(storageText: $0, source: .nextInput) }
        let merged = NextInputCandidateMerger.merged(
            preferred: session.candidateModels,
            learned: visibleGenerated,
            limit: session.candidates.count + visibleGenerated.count
        )
        guard merged != session.candidateModels else { return false }
        session.updateCandidates(merged)
        return true
    }

    public func isSuppressed(_ candidate: String, after context: String) -> Bool {
        store.isSuppressed(candidate, after: context)
    }

    public func forgetLearnedCandidate(_ candidate: String) {
        store.forgetLearnedCandidate(candidate)
    }

    public func suppressSelectedCandidate() throws {
        guard let candidate = session.selectedCandidate,
              let context = session.context else { return }
        defer { _ = session.removeSelectedCandidate() }
        try store.suppress(candidate, after: context)
    }

    public func suppressLearnedCandidate(_ candidate: String) throws {
        try store.suppress(candidate, after: "learnedCompound")
    }

    public func pageRange(pageSize: Int) -> Range<Int> {
        LinearCandidateNavigator.pageRange(
            containing: session.selectedIndex,
            pageSize: pageSize,
            candidateCount: session.candidateModels.count
        )
    }

    public func linearSelectionIndex(offset: Int) -> Int? {
        session.linearSelectionIndex(offset: offset)
    }

    public func wrappedSelectionIndex(offset: Int) -> Int? {
        session.wrappedSelectionIndex(offset: offset)
    }

    @discardableResult
    public func select(index: Int) -> String? {
        session.select(index: index)
    }

    public func clearCandidates() {
        session.clearCandidates()
    }

    public func resetCandidates() {
        session.reset()
    }

    public func breakSequence() {
        cursor = NextInputSequenceCursor()
    }

    public func removeAllLearning() throws {
        cursor = NextInputSequenceCursor()
        try store.removeAll()
    }

    public func flush() {
        store.flush()
    }
}
