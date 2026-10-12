public final class CandidateSearchCoordinator {
    private let session: CandidateSearchSession

    public init(session: CandidateSearchSession = CandidateSearchSession()) {
        self.session = session
    }

    public func query(for kind: CandidateSearchKind) -> String? {
        session.query(for: kind)
    }

    public func activate(
        _ kind: CandidateSearchKind,
        query: String
    ) {
        _ = session.begin(kind, query: query)
    }

    public func cancel(_ kind: CandidateSearchKind) {
        session.cancel(kind)
    }

    public func cancelAll() {
        session.cancelAll()
    }

    public func start<Value: Sendable>(
        _ kind: CandidateSearchKind,
        query: String,
        operation: @escaping @MainActor () async throws -> Value,
        validate: @escaping @MainActor () -> Bool,
        apply: @escaping @MainActor (Value) -> Void,
        retainQueryAfterCompletion: Bool = true,
        onCancel: (@MainActor () -> Void)? = nil,
        onError: (@MainActor (Error) -> Void)? = nil
    ) {
        let token = session.begin(kind, query: query)
        let session = session
        let task = Task { @MainActor in
            defer {
                if retainQueryAfterCompletion {
                    session.finishTask(token)
                } else {
                    session.complete(token)
                }
            }
            do {
                let value = try await operation()
                try Task.checkCancellation()
                guard session.isCurrent(token), validate() else {
                    return
                }
                apply(value)
            } catch is CancellationError {
                onCancel?()
            } catch {
                onError?(error)
            }
        }
        session.attach(task, to: token)
    }
}
