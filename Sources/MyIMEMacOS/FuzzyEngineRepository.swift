import Foundation
import MyIMECore

/// Shares the expensive typo-correction index between input controllers.
/// IMK creates a controller for each client application, so keeping this index
/// on each controller multiplies its memory usage.
final class FuzzyEngineRepository: @unchecked Sendable {
    private let lock = NSLock()
    private var cachedEntries: [DictionaryEntry] = []
    private var cachedBaseKey: String?
    private var cachedUserEntries: [DictionaryEntry] = []
    private var preparingBaseKey: String?
    private var preparingUserEntries: [DictionaryEntry] = []
    private var cachedEngine = FuzzyConversionEngine(entries: [])
    private var generation = 0

    @discardableResult
    func prepare(for entries: [DictionaryEntry]) -> Int {
        lock.lock()
        defer { lock.unlock() }

        if entries == cachedEntries {
            return generation
        }

        let engine = FuzzyConversionEngine(entries: entries)
        cachedEntries = entries
        cachedEngine = engine
        generation += 1
        return generation
    }

    @discardableResult
    func prepare(
        baseEntries: [DictionaryEntry],
        baseKey: String,
        userEntries: [DictionaryEntry]
    ) -> Int {
        lock.lock()
        if cachedBaseKey == baseKey, cachedUserEntries == userEntries {
            let currentGeneration = generation
            lock.unlock()
            return currentGeneration
        }
        if preparingBaseKey == baseKey,
           preparingUserEntries == userEntries {
            let currentGeneration = generation
            lock.unlock()
            return currentGeneration
        }
        preparingBaseKey = baseKey
        preparingUserEntries = userEntries
        lock.unlock()

        let engine = FuzzyConversionEngine(
            entries: userEntries + baseEntries
        )

        lock.lock()
        defer { lock.unlock() }
        guard preparingBaseKey == baseKey,
              preparingUserEntries == userEntries else {
            return generation
        }
        cachedEngine = engine
        cachedEntries = []
        cachedBaseKey = baseKey
        cachedUserEntries = userEntries
        preparingBaseKey = nil
        preparingUserEntries = []
        generation += 1
        return generation
    }

    func matches(
        for input: String,
        maximumDistance: Int? = nil,
        limit: Int
    ) -> [FuzzyConversionMatch] {
        lock.lock()
        let engine = cachedEngine
        lock.unlock()
        return engine.matches(
            for: input,
            maximumDistance: maximumDistance,
            limit: limit
        )
    }
}
