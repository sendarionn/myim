import Foundation
import Testing
@testable import MyIMECore

struct DictionaryCacheTests {
    @Test
    func savesDictionaryAndMetadata() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = DictionaryCache(directoryURL: directory)
        let syncedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let metadata = DictionaryCacheMetadata(
            syncedAt: syncedAt,
            entryCount: 2
        )

        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        try cache.save(
            dictionaryText: "miru\n 見る\n",
            metadata: metadata
        )

        #expect(cache.containsDictionary())
        #expect(
            try String(contentsOf: cache.dictionaryURL, encoding: .utf8)
                == "miru\n 見る\n"
        )
        #expect(try cache.loadMetadata() == metadata)
    }
}
