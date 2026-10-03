public final class UserDictionaryStore {
    public typealias Persistence = ([DictionaryEntry]) throws -> Void

    public private(set) var entries: [DictionaryEntry]
    private let persist: Persistence

    public init(
        entries: [DictionaryEntry],
        persist: @escaping Persistence
    ) {
        self.entries = entries
        self.persist = persist
    }

    public var count: Int {
        entries.count
    }

    @discardableResult
    public func add(
        reading: String,
        candidate: String,
        display: String? = nil
    ) throws -> Bool {
        let updated = UserDictionaryEditor.adding(
            reading: reading,
            candidate: candidate,
            display: display,
            to: entries
        )
        let changed = updated != entries
        entries = updated
        try persist(entries)
        return changed
    }

    public func canRemove(candidate: String) -> Bool {
        UserDictionaryEditor.removing(candidate: candidate, from: entries)
            != entries
    }

    public func canRemove(
        candidate: String,
        matchingReadings readings: [String]
    ) -> Bool {
        UserDictionaryEditor.removing(
            candidate: candidate,
            matchingReadings: readings,
            from: entries
        ) != entries
    }

    @discardableResult
    public func remove(candidate: String) throws -> Bool {
        try replaceAndPersist(
            UserDictionaryEditor.removing(
                candidate: candidate,
                from: entries
            )
        )
    }

    @discardableResult
    public func remove(
        candidate: String,
        matchingReadings readings: [String]
    ) throws -> Bool {
        try replaceAndPersist(
            UserDictionaryEditor.removing(
                candidate: candidate,
                matchingReadings: readings,
                from: entries
            )
        )
    }

    @discardableResult
    public func replaceEntriesIfChanged(
        _ entries: [DictionaryEntry]
    ) -> Bool {
        guard entries != self.entries else { return false }
        self.entries = entries
        return true
    }

    public func restore(_ entries: [DictionaryEntry]) {
        self.entries = entries
    }

    private func replaceAndPersist(
        _ updated: [DictionaryEntry]
    ) throws -> Bool {
        guard updated != entries else { return false }
        entries = updated
        try persist(entries)
        return true
    }
}
