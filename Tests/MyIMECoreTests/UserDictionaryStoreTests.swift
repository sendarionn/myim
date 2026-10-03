import Testing
@testable import MyIMECore

@Suite
struct UserDictionaryStoreTests {
    @Test
    func addsAndPersistsEntriesAsOneOperation() throws {
        var persisted: [DictionaryEntry] = []
        let store = UserDictionaryStore(entries: []) {
            persisted = $0
        }

        let changed = try store.add(
            reading: "rlj",
            candidate: "リモートロックジャパン"
        )

        #expect(changed)
        #expect(store.entries == persisted)
        #expect(store.entries.first?.input == "rlj")
        #expect(
            store.entries.first?.candidates == ["リモートロックジャパン"]
        )
    }

    @Test
    func removesOnlyTheMatchingReadingAndPersistsTheResult() throws {
        var persisted: [DictionaryEntry] = []
        let store = UserDictionaryStore(
            entries: [
                DictionaryEntry(reading: "miru", candidates: ["見る"]),
                DictionaryEntry(reading: "kanmiru", candidates: ["見る"])
            ],
            persist: { persisted = $0 }
        )

        let removed = try store.remove(
            candidate: "見る",
            matchingReadings: ["miru"]
        )

        #expect(removed)
        #expect(store.entries == persisted)
        #expect(store.entries.map(\.input) == ["kanmiru"])
    }

    @Test
    func reloadReplacesEntriesOnlyWhenDiskContentChanges() {
        let original = [
            DictionaryEntry(reading: "a", candidates: ["A"])
        ]
        let replacement = [
            DictionaryEntry(reading: "b", candidates: ["B"])
        ]
        let store = UserDictionaryStore(entries: original) { _ in }

        #expect(!store.replaceEntriesIfChanged(original))
        #expect(store.replaceEntriesIfChanged(replacement))
        #expect(store.entries == replacement)
    }
}
