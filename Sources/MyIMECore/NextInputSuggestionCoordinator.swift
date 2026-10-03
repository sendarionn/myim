import Foundation

public final class NextInputSuggestionCoordinator {
    private var predictionModel: NextInputPredictionModel
    private var session = NextInputCandidateSession()
    private let writer: DeferredJSONFileWriter<NextInputPredictionModel>

    public init(
        predictionModel: NextInputPredictionModel,
        writer: DeferredJSONFileWriter<NextInputPredictionModel>
    ) {
        self.predictionModel = predictionModel
        self.writer = writer
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

    public var context: String? {
        session.context
    }

    public func candidatesAfterLastInput(limit: Int) -> [String] {
        predictionModel.candidatesAfterLastInput(limit: limit)
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
            predictionModel.breakSequence()
        }
        if learningEnabled {
            predictionModel.record(tokens: committedTokens, source: learningSource)
            writer.schedule(predictionModel)
        }
        let predictions: [NextInputPrediction]
        if learningEnabled {
            predictions = predictionModel.predictionsAfterLastInput(limit: limit)
        } else {
            predictions = predictionModel.predictions(after: value, limit: limit)
        }
        return predictions.map(NextInputCandidateMetadata.candidate)
    }

    public func beginSuggestions(
        context: String,
        preferredCandidates: [String],
        learnedCandidates: [String],
        dictionaryCandidates: [String],
        unsuppressibleCandidates: Set<String> = []
    ) {
        beginSuggestions(
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

    public func beginSuggestions(
        context: String,
        preferredCandidates: [Candidate],
        learnedCandidates: [Candidate],
        dictionaryCandidates: [Candidate],
        unsuppressibleCandidates: Set<String> = []
    ) {
        let visibleDictionaryCandidates = dictionaryCandidates.filter {
            !predictionModel.isSuppressed($0.commitText, after: context)
        }
        let visiblePreferredCandidates = preferredCandidates.filter {
            unsuppressibleCandidates.contains($0.commitText)
                || !predictionModel.isSuppressed($0.commitText, after: context)
        }
        let candidates = NextInputCandidateMerger.merged(
            preferred: visiblePreferredCandidates,
            learned: learnedCandidates + visibleDictionaryCandidates,
            limit: visiblePreferredCandidates.count
                + learnedCandidates.count
                + visibleDictionaryCandidates.count
        )
        session.begin(context: context, candidates: candidates)
    }

    @discardableResult
    public func appendGeneratedCandidates(
        _ generated: [String],
        after context: String
    ) -> Bool {
        let visibleGenerated = generated.filter {
            !predictionModel.isSuppressed($0, after: context)
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
        predictionModel.isSuppressed(candidate, after: context)
    }

    public func forgetLearnedCandidate(_ candidate: String) {
        predictionModel.forgetLearnedCandidate(candidate)
        writer.schedule(predictionModel)
    }

    public func suppressSelectedCandidate() throws {
        guard let candidate = session.selectedCandidate,
              let context = session.context else { return }
        predictionModel.suppress(candidate, after: context)
        defer { _ = session.removeSelectedCandidate() }
        try writer.writeImmediately(predictionModel)
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

    public func resetSuggestions() {
        session.reset()
    }

    public func breakSequence() {
        predictionModel.breakSequence()
    }

    public func removeAllLearning() throws {
        predictionModel.removeAll()
        try writer.writeImmediately(predictionModel)
    }

    public func flush() {
        writer.flush()
    }
}
