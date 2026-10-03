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

    public var hasCandidates: Bool {
        !session.candidates.isEmpty
    }

    public var selectedIndex: Int? {
        session.selectedIndex
    }

    public var selectedCandidate: String? {
        session.selectedCandidate
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
        guard predictionEnabled else { return [] }
        if breakPreviousSequence {
            predictionModel.breakSequence()
        }
        if learningEnabled {
            predictionModel.record(value)
            writer.schedule(predictionModel)
        }
        return predictionModel.candidates(after: value, limit: limit)
    }

    public func beginSuggestions(
        context: String,
        preferredCandidates: [String],
        learnedCandidates: [String],
        dictionaryCandidates: [String],
        unsuppressibleCandidates: Set<String> = []
    ) {
        let visibleDictionaryCandidates = dictionaryCandidates.filter {
            !predictionModel.isSuppressed($0, after: context)
        }
        let visiblePreferredCandidates = preferredCandidates.filter {
            unsuppressibleCandidates.contains($0)
                || !predictionModel.isSuppressed($0, after: context)
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
        }
        let merged = NextInputCandidateMerger.merged(
            preferred: session.candidates,
            learned: visibleGenerated,
            limit: session.candidates.count + visibleGenerated.count
        )
        guard merged != session.candidates else { return false }
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
            candidateCount: session.candidates.count
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
