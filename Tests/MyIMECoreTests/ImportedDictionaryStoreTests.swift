import Foundation
import Testing
@testable import MyIMECore

@Suite
struct ImportedDictionaryStoreTests {
    @Test
    func importsSKKAsIndependentTSVAndReloadsIt() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ImportedDictionaryStore(directoryURL: directory)

        let summary = try store.importSKK(
            data: Data("けいおう /慶應/\nだいがく /大学/".utf8),
            sourceFilename: "SKK-JISYO.test"
        )

        #expect(summary.fileURL.lastPathComponent == "SKK-JISYO.test.tsv")
        #expect(summary.readingCount == 2)
        #expect(summary.candidateCount == 2)
        #expect(store.loadDictionaries().map { $0.fileURL.lastPathComponent } == [
            "SKK-JISYO.test.tsv"
        ])
        #expect(store.loadLayers() == [[
            DictionaryEntry(reading: "けいおう", candidates: ["慶應"]),
            DictionaryEntry(reading: "だいがく", candidates: ["大学"])
        ]])
    }

    @Test
    func importingSameSourceReplacesOnlyItsIndependentDictionary() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ImportedDictionaryStore(directoryURL: directory)

        _ = try store.importSKK(
            data: Data("よみ /旧/".utf8),
            sourceFilename: "sample.dic"
        )
        _ = try store.importSKK(
            data: Data("よみ /新/".utf8),
            sourceFilename: "sample.dic"
        )

        #expect(store.loadLayers() == [[
            DictionaryEntry(reading: "よみ", candidates: ["新"])
        ]])
    }
}
