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
        let first = sourceDirectory.appendingPathComponent("SKK-JISYO.L")
        let second = sourceDirectory.appendingPathComponent("SKK-JISYO.geo")
        let third = sourceDirectory.appendingPathComponent("SKK-JISYO.jinmei")
        try Data("けいおう /慶應/\n".utf8).write(to: first)
        try Data("だいがく /大学/代学/\n".utf8).write(to: second)
        try Data("やまだ /山田/\n".utf8).write(to: third)
        let store = ImportedDictionaryStore(directoryURL: directory)
        var importedFilenames: [String] = []

        let summary = try store.importSKKFiles([first, second, third]) {
            importedFilenames.append($0.fileURL.lastPathComponent)
        }

        #expect(summary.readingCount == 3)
        #expect(summary.candidateCount == 4)
        #expect(summary.description == "読み 3件、候補 4件、対象外 0件")
        #expect(importedFilenames == [
            "SKK-JISYO.L.tsv",
            "SKK-JISYO.geo.tsv",
            "SKK-JISYO.jinmei.tsv"
        ])
        #expect(store.loadDictionaries().map(\.fileURL.lastPathComponent) == [
            "SKK-JISYO.L.tsv",
            "SKK-JISYO.geo.tsv",
            "SKK-JISYO.jinmei.tsv"
        ])
    }

    @Test
    func laterImportsKeepExistingIndependentDictionaries() throws {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.removeItem(at: source)
        }
        try FileManager.default.createDirectory(
            at: source,
            withIntermediateDirectories: true
        )
        let urls = ["L", "geo", "jinmei"].map {
            source.appendingPathComponent("SKK-JISYO.\($0)")
        }
        for (index, url) in urls.enumerated() {
            try Data("よみ\(index) /候補\(index)/\n".utf8).write(to: url)
        }
        let store = ImportedDictionaryStore(directoryURL: destination)

        _ = try store.importSKKFiles([urls[0]])
        _ = try store.importSKKFiles(Array(urls.dropFirst()))

        #expect(store.loadDictionaries().map(\.fileURL.lastPathComponent) == [
            "SKK-JISYO.L.tsv",
            "SKK-JISYO.geo.tsv",
            "SKK-JISYO.jinmei.tsv"
        ])
    }

    @Test
    func sameFilenameFromDifferentDirectoriesUsesTheSameStoredFile() throws {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let firstDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let secondDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.removeItem(at: firstDirectory)
            try? FileManager.default.removeItem(at: secondDirectory)
        }
        try FileManager.default.createDirectory(
            at: firstDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: secondDirectory,
            withIntermediateDirectories: true
        )
        let first = firstDirectory.appendingPathComponent("SKK-JISYO.same")
        let second = secondDirectory.appendingPathComponent("SKK-JISYO.same")
        try Data("よみ /最初/\n".utf8).write(to: first)
        try Data("よみ /後/\n".utf8).write(to: second)
        let store = ImportedDictionaryStore(directoryURL: destination)

        _ = try store.importSKKFiles([first, second])

        let dictionaries = store.loadDictionaries()
        #expect(dictionaries.count == 1)
        #expect(dictionaries.first?.fileURL.lastPathComponent
            == "SKK-JISYO.same.tsv")
        #expect(dictionaries.first?.entries == [
            DictionaryEntry(reading: "よみ", candidates: ["後"])
        ])
    }
}
