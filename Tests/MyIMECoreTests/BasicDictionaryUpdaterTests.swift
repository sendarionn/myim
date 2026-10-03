import Foundation
import Testing
@testable import MyIMECore

@Suite
struct BasicDictionaryUpdaterTests {
    @Test
    func savesASnapshotNewerThanTheBundledRevision() throws {
        let cache = makeCache()
        defer { try? FileManager.default.removeItem(at: cache.directoryURL) }
        let updater = BasicDictionaryUpdater(
            cache: cache,
            bundledRevision: "2026-01-01"
        )

        let result = try updater.apply(snapshot("2026-02-01"), syncedAt: Date())

        #expect(result == .updated(snapshot("2026-02-01")))
        #expect(try cache.loadMetadata()?.sourceRevision == "2026-02-01")
        #expect(try cache.loadMetadata()?.sourceEntryCount == 10)
    }

    @Test
    func keepsTheCacheWhenTheSnapshotIsNotNewer() throws {
        let cache = makeCache()
        defer { try? FileManager.default.removeItem(at: cache.directoryURL) }
        let updater = BasicDictionaryUpdater(
            cache: cache,
            bundledRevision: "2026-02-01"
        )

        let result = try updater.apply(snapshot("2026-02-01"), syncedAt: Date())

        #expect(result == .alreadyLatest(snapshot("2026-02-01")))
        #expect(!cache.containsDictionary())
    }

    @Test
    func comparesWithTheCachedRevisionBeforeTheBundledOne() throws {
        let cache = makeCache()
        defer { try? FileManager.default.removeItem(at: cache.directoryURL) }
        let updater = BasicDictionaryUpdater(
            cache: cache,
            bundledRevision: "2026-01-01"
        )
        _ = try updater.apply(snapshot("2026-03-01"), syncedAt: Date())

        let result = try updater.apply(snapshot("2026-02-01"), syncedAt: Date())

        #expect(result == .alreadyLatest(snapshot("2026-02-01")))
    }

    @Test
    func savesAnySnapshotWithoutAKnownRevision() throws {
        let cache = makeCache()
        defer { try? FileManager.default.removeItem(at: cache.directoryURL) }
        let updater = BasicDictionaryUpdater(cache: cache, bundledRevision: nil)

        #expect(try updater.apply(snapshot("2000-01-01"), syncedAt: Date())
            == .updated(snapshot("2000-01-01")))
    }

    @Test
    func describesTheStatusShownInTheStatusAlert() {
        #expect(BasicDictionaryStatus.unchecked.description == "未確認")
        #expect(BasicDictionaryStatus.checking.isChecking)
        #expect(BasicDictionaryStatus.updated(readingCount: 3).description
            == "更新完了（3読み）")
        #expect(BasicDictionaryStatus.latest(readingCount: 3).description
            == "最新版（3読み）")
    }

    private func makeCache() -> DictionaryCache {
        DictionaryCache(directoryURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString))
    }

    private func snapshot(_ generatedAt: String) -> TKGDictionarySnapshot {
        TKGDictionarySnapshot(
            generatedAt: generatedAt,
            sourceEntryCount: 10,
            dictionaryText: "kouho\t候補\n",
            entries: [DictionaryEntry(reading: "kouho", candidates: ["候補"])]
        )
    }
}
