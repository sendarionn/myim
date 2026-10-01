public final class SuggestionSearchCoordinator {
    private let session: SuggestionSearchSession

    public init(session: SuggestionSearchSession = SuggestionSearchSession()) {
        self.session = session
    }

    public func query(for kind: SuggestionSearchKind) -> String? {
        session.query(for: kind)
    }

    public func activate(
        _ kind: SuggestionSearchKind,
        query: String
    ) {
        _ = session.begin(kind, query: query)
    }

    public func cancel(_ kind: SuggestionSearchKind) {
        session.cancel(kind)
    }

    public func cancelAll() {
        session.cancelAll()
    }

    public func start<Value: Sendable>(
        _ kind: SuggestionSearchKind,
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
