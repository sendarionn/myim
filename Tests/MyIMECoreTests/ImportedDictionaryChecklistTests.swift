import Foundation
import Testing
@testable import MyIMECore

@Suite
struct ImportedDictionaryChecklistTests {
    @Test
    func listsEveryDictionaryAndKeepsIndependentEnabledStates() {
        let dictionaries = ["SKK-JISYO.L.tsv", "SKK-JISYO.geo.tsv", "SKK-JISYO.jinmei.tsv"]
            .map {
                ImportedDictionary(
                    fileURL: URL(fileURLWithPath: "/tmp/\($0)"),
                    entries: [DictionaryEntry(
                        reading: $0,
                        candidates: [$0]
                    )]
                )
            }

        #expect(ImportedDictionaryChecklist.items(
            dictionaries: dictionaries,
            disabledFilenames: ["SKK-JISYO.geo.tsv"]
        ) == [
            ImportedDictionaryChecklistItem(
                filename: "SKK-JISYO.L.tsv",
                isEnabled: true
            ),
            ImportedDictionaryChecklistItem(
                filename: "SKK-JISYO.geo.tsv",
                isEnabled: false
            ),
            ImportedDictionaryChecklistItem(
                filename: "SKK-JISYO.jinmei.tsv",
                isEnabled: true
            )
        ])
    }
}
