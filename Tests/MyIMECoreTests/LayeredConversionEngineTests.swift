import Testing
@testable import MyIMECore

@Suite
struct LayeredConversionEngineTests {
    @Test
    func preservesSourcePriorityWithoutRebuildingIndexes() {
        let engine = LayeredConversionEngine(engines: [
            ConversionEngine(entries: [
                DictionaryEntry(reading: "よみ", candidates: ["ユーザー", "共通"])
            ]),
            ConversionEngine(entries: [
                DictionaryEntry(reading: "よみ", candidates: ["独立辞書", "共通"])
            ])
        ])

        #expect(engine.candidates(for: "よみ") == ["ユーザー", "共通", "独立辞書"])
    }

    @Test
    func mergesContinuationSourcesInPriorityOrder() {
        let generator = LayeredDictionaryContinuationCandidateGenerator(
            generators: [
                DictionaryContinuationCandidateGenerator(entries: [
                    DictionaryEntry(reading: "a", candidates: ["よろしくお願いします"])
                ]),
                DictionaryContinuationCandidateGenerator(entries: [
                    DictionaryEntry(reading: "b", candidates: ["よろしくお願いいたします"])
                ])
            ]
        )

        #expect(generator.candidates(after: "よろしく") == [
            "お願いします", "お願いいたします"
        ])
    }
}
