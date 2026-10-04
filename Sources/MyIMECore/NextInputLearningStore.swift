import Foundation

/// Next-input knowledge shared by every input client in the process
///
/// Each InputController keeps its own `NextInputSequenceCursor` and
/// candidate session, but learns into and predicts from this one model so
/// controllers never overwrite each other's history when persisting
public final class NextInputLearningStore {
    private var model: NextInputPredictionModel
    private let writer: DeferredJSONFileWriter<NextInputPredictionModel>

    public init(
        model: NextInputPredictionModel,
        writer: DeferredJSONFileWriter<NextInputPredictionModel>
    ) {
        self.model = model
        self.writer = writer
    }

    public var snapshot: NextInputPredictionModel {
        model
    }

    public func record(
        tokens: [String],
        source: NextInputLearningSource,
        cursor: inout NextInputSequenceCursor
    ) {
        model.record(tokens: tokens, source: source, cursor: &cursor)
        writer.schedule(model)
    }

    public func predictions(
        after cursor: NextInputSequenceCursor,
        limit: Int
    ) -> [NextInputPrediction] {
        model.predictions(after: cursor, limit: limit)
    }

    public func predictions(after value: String, limit: Int)
        -> [NextInputPrediction] {
        model.predictions(after: value, limit: limit)
    }

    public func isSuppressed(_ candidate: String, after context: String) -> Bool {
        model.isSuppressed(candidate, after: context)
    }

    public func suppress(_ candidate: String, after context: String) throws {
        model.suppress(candidate, after: context)
        try writer.writeImmediately(model)
    }

    public func forgetLearnedCandidate(_ candidate: String) {
        model.forgetLearnedCandidate(candidate)
        writer.schedule(model)
    }

    public func removeAll() throws {
        model.removeAll()
        try writer.writeImmediately(model)
    }

    public func flush() {
        writer.flush()
    }
}
