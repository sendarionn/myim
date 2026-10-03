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

    @Test
    func importsSeveralSKKFilesAndTotalsTheirCounts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: sourceDirectory)
        }
        try FileManager.default.createDirectory(
            at: sourceDirectory,
            withIntermediateDirectories: true
        )
        let first = sourceDirectory.appendingPathComponent("a.dic")
        let second = sourceDirectory.appendingPathComponent("b.dic")
        try Data("けいおう /慶應/\n".utf8).write(to: first)
        try Data("だいがく /大学/代学/\n".utf8).write(to: second)
        let store = ImportedDictionaryStore(directoryURL: directory)
        var importedFilenames: [String] = []

        let summary = try store.importSKKFiles([first, second]) {
            importedFilenames.append($0.fileURL.lastPathComponent)
        }

        #expect(summary.readingCount == 2)
        #expect(summary.candidateCount == 3)
        #expect(summary.description == "読み 2件、候補 3件、対象外 0件")
        #expect(importedFilenames == ["a.dic.tsv", "b.dic.tsv"])
    }
}
