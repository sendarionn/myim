import Foundation
import Testing
@testable import MyIMECore

@Suite
struct ConversionDictionaryRuntimeTests {
    @Test
    func layersUserEntriesBeforeEnabledImportedDictionaries() {
        let runtime = makeRuntime(
            userEntries: [DictionaryEntry(reading: "kouho", candidates: ["候補"])],
            disabled: ["b.tsv"]
        )

        #expect(runtime.userEngine.candidates(for: "kouho") == ["候補", "公募"])
        #expect(runtime.enabledImportedFilenames(excluding: ["b.tsv"]) == ["a.tsv"])
    }

    @Test
    func rebuildsUserLayersWhenEntriesOrEnabledDictionariesChange() {
        var runtime = makeRuntime(disabled: ["b.tsv"])

        runtime.rebuildUserLayers(
            userEntries: [DictionaryEntry(reading: "kouho", candidates: ["校舎"])],
            disabledImportedFilenames: ["a.tsv"]
        )

        #expect(runtime.userEngine.candidates(for: "kouho") == ["校舎", "後方"])
        #expect(runtime.continuationCandidates(after: "校舎", limit: 4).isEmpty)
    }

    @Test
    func replacingImportedDictionariesKeepsUserEntries() {
        var runtime = makeRuntime(
            userEntries: [DictionaryEntry(reading: "kouho", candidates: ["候補"])],
            disabled: []
        )

        runtime.replaceImported(
            ImportedDictionaryRuntime(dictionaries: [
                imported("c.tsv", reading: "kouho", candidate: "工法")
            ]),
            userEntries: [DictionaryEntry(reading: "kouho", candidates: ["候補"])],
            disabledImportedFilenames: []
        )

        #expect(runtime.imported.filenames == ["c.tsv"])
        #expect(runtime.userEngine.candidates(for: "kouho") == ["候補", "工法"])
    }

    @Test
    func replacingBasicEntriesRebuildsBasicEngineAndContinuations() {
        var runtime = makeRuntime(disabled: [])
        #expect(runtime.basicEngine.candidates(for: "ki").isEmpty)

        runtime.replaceBasicEntries([
            DictionaryEntry(reading: "ki", candidates: ["木"]),
            DictionaryEntry(reading: "yoroshikuonegai", candidates: ["よろしくお願い"])
        ])

        #expect(runtime.basicEntries.count == 2)
        #expect(runtime.basicEngine.candidates(for: "ki") == ["木"])
        #expect(runtime.continuationCandidates(after: "よろしく", limit: 4)
            == ["お願い"])
    }

    @Test
    func resolvesReadingsAcrossDictionariesWithoutDuplicates() {
        let runtime = makeRuntime(
            userEntries: [DictionaryEntry(reading: "kouho", candidates: ["候補"])],
            disabled: [],
            basicEntries: [
                DictionaryEntry(reading: "kouho", candidates: ["候補"]),
                DictionaryEntry(reading: "kôho", candidates: ["候補"])
            ]
        )

        #expect(runtime.readings(for: "候補") == ["kouho", "kôho"])
    }

    private func makeRuntime(
        userEntries: [DictionaryEntry] = [],
        disabled: Set<String>,
        basicEntries: [DictionaryEntry] = []
    ) -> ConversionDictionaryRuntime {
        ConversionDictionaryRuntime(
            userEntries: userEntries,
            imported: ImportedDictionaryRuntime(dictionaries: [
                imported("a.tsv", reading: "kouho", candidate: "公募"),
                imported("b.tsv", reading: "kouho", candidate: "後方")
            ]),
            disabledImportedFilenames: disabled,
            basicEntries: basicEntries,
            basicEngine: ConversionEngine(entries: basicEntries),
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: basicEntries
            ),
            compoundGenerator: CompoundDictionaryCandidateGenerator(
                entries: basicEntries
            ),
            systemEngine: IndexedDictionaryEngine()
        )
    }

    private func imported(
        _ filename: String,
        reading: String,
        candidate: String
    ) -> ImportedDictionary {
        ImportedDictionary(
            fileURL: URL(fileURLWithPath: "/tmp/\(filename)"),
            entries: [DictionaryEntry(reading: reading, candidates: [candidate])]
        )
    }
}
