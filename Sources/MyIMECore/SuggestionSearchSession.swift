import Foundation

public enum SuggestionSearchKind: Hashable, Sendable {
    case calendarFormat
    case dictionaryDefinition
    case official
    case fuzzy
    case fuzzyIndexBuild
    case javaScriptExtensions
    case nextInputExtension
    case postalAddress
    case translation
}

public final class SuggestionSearchSession: @unchecked Sendable {
    public struct Token: Equatable, Sendable {
        fileprivate let id: UUID
        public let kind: SuggestionSearchKind
        public let query: String
    }

    private struct Entry {
        let token: Token
        var task: Task<Void, Never>?
    }

    private let lock = NSLock()
    private var entries: [SuggestionSearchKind: Entry] = [:]

    public init() {}

    public func begin(
        _ kind: SuggestionSearchKind,
        query: String
    ) -> Token {
        let token = Token(id: UUID(), kind: kind, query: query)
        lock.lock()
        let previousTask = entries[kind]?.task
        entries[kind] = Entry(token: token, task: nil)
        lock.unlock()
        previousTask?.cancel()
        return token
    }

    public func attach(_ task: Task<Void, Never>, to token: Token) {
        lock.lock()
        guard entries[token.kind]?.token == token else {
            lock.unlock()
            task.cancel()
            return
        }
        entries[token.kind]?.task = task
        lock.unlock()
    }

    public func isCurrent(_ token: Token) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return entries[token.kind]?.token == token
    }

    public func complete(_ token: Token) {
        lock.lock()
        if entries[token.kind]?.token == token {
            entries.removeValue(forKey: token.kind)
        }
        lock.unlock()
    }

    public func finishTask(_ token: Token) {
        lock.lock()
        if entries[token.kind]?.token == token {
            entries[token.kind]?.task = nil
        }
        lock.unlock()
    }

    public func query(for kind: SuggestionSearchKind) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return entries[kind]?.token.query
    }

    public func cancel(_ kind: SuggestionSearchKind) {
        lock.lock()
        let task = entries.removeValue(forKey: kind)?.task
        lock.unlock()
        task?.cancel()
    }

    public func cancelAll() {
        lock.lock()
        let tasks = entries.values.compactMap(\.task)
        entries.removeAll()
        lock.unlock()
        tasks.forEach { $0.cancel() }
    }
}
