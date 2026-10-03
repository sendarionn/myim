import Foundation
import Testing
@testable import MyIMECore

@Suite
struct CandidateFilterIDSStoreTests {
    @Test
    func readsOnlySupportedFilesInNameOrder() throws {
        let store = try makeStore()
        try FileManager.default.createDirectory(
            at: store.directoryURL,
            withIntermediateDirectories: true
        )
        try "b".write(to: store.directoryURL.appendingPathComponent("b.ids"), atomically: true, encoding: .utf8)
        try "a".write(to: store.directoryURL.appendingPathComponent("a.TXT"), atomically: true, encoding: .utf8)
        try "x".write(to: store.directoryURL.appendingPathComponent("x.json"), atomically: true, encoding: .utf8)

        #expect(store.supplementalTexts() == ["a", "b"])
        #expect(store.signature().map { $0.components(separatedBy: ":")[0] }
            == ["a.TXT", "b.ids"])
    }

    @Test
    func preparesTheDirectoryWithoutOverwritingTheGuide() throws {
        let store = try makeStore()
        try store.prepareDirectory()
        let guideURL = store.directoryURL.appendingPathComponent("README.txt")
        #expect(try String(contentsOf: guideURL, encoding: .utf8)
            == CandidateFilterIDSStore.guide)

        try "edited".write(to: guideURL, atomically: true, encoding: .utf8)
        try store.prepareDirectory()

        #expect(try String(contentsOf: guideURL, encoding: .utf8) == "edited")
        #expect(store.supplementalTexts() == ["edited"])
    }

    @Test
    func savesDownloadedIDSWithItsSource() throws {
        let store = try makeStore()

        try store.saveCJKVIIDS(Data("U+4F11\t休\t⿰亻木".utf8), downloadedAt: Date())

        #expect(store.supplementalTexts() == ["U+4F11\t休\t⿰亻木"])
        let source = try String(
            contentsOf: store.directoryURL
                .appendingPathComponent("cjkvi-ids-source.md"),
            encoding: .utf8
        )
        #expect(source.contains("github.com/cjkvi/cjkvi-ids"))
    }

    @Test
    func reloadsTheDatabaseOnlyAfterTheIDSFilesChange() throws {
        let store = try makeStore()
        try store.prepareDirectory()
        var cache = CandidateFilterDatabaseCache(bundledText: "", store: store)
        #expect(cache.database.attributes(for: "休")?.components.isEmpty != false)

        try "U+4F11\t休\t⿰亻木".write(
            to: store.directoryURL.appendingPathComponent("ids.txt"),
            atomically: true,
            encoding: .utf8
        )
        cache.refreshIfChanged()

        #expect(cache.database.attributes(for: "休")?.components.contains("亻") == true)
    }

    private func makeStore() throws -> CandidateFilterIDSStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CandidateFilterIDSStoreTests-\(UUID().uuidString)")
        return CandidateFilterIDSStore(directoryURL: directory)
    }
}
