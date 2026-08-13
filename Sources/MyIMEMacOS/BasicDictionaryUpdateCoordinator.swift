import Foundation
import MyIMECore

/// Coalesces automatic TKGJE update checks requested by IMK controllers
/// created for different client applications
actor BasicDictionaryUpdateCoordinator {
    typealias FetchOperation = @Sendable () async throws
        -> TKGDictionarySnapshot

    private let automaticCheckInterval: TimeInterval
    private let fetchOperation: FetchOperation
    private var lastSuccessfulCheck: Date?
    private var inFlightTask: Task<TKGDictionarySnapshot, Error>?

    init(
        automaticCheckInterval: TimeInterval = 6 * 60 * 60,
        fetchOperation: @escaping FetchOperation = {
            try await TKGDictionaryClient().fetch()
        }
    ) {
        self.automaticCheckInterval = automaticCheckInterval
        self.fetchOperation = fetchOperation
    }

    func fetchIfNeeded(
        force: Bool,
        now: Date = Date()
    ) async throws -> TKGDictionarySnapshot? {
        if let inFlightTask {
            return try await inFlightTask.value
        }
        if !force,
           let lastSuccessfulCheck,
           now.timeIntervalSince(lastSuccessfulCheck)
            < automaticCheckInterval {
            return nil
        }

        let operation = fetchOperation
        let task = Task {
            try await operation()
        }
        inFlightTask = task
        do {
            let snapshot = try await task.value
            lastSuccessfulCheck = now
            inFlightTask = nil
            return snapshot
        } catch {
            inFlightTask = nil
            throw error
        }
    }
}
