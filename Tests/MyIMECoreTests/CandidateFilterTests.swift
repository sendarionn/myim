import Testing
@testable import MyIMECore

@Suite
struct CandidateFilterTests {
    private let database = KanjiFilterDatabase(values: [
        "校": KanjiFilterAttributes(radical: "木", strokeCount: 10, components: ["木", "交"]),
        "構": KanjiFilterAttributes(radical: "木", strokeCount: 14, components: ["木"]),
        "星": KanjiFilterAttributes(radical: "日", strokeCount: 9, components: ["日", "生"])
    ])

    @Test
    func filtersDirectStringAttributesWithAndConditions() {
        let result = CandidateFilter().filtered(
            ["構成", "こうせい", "コウセイ", "A構成"],
            conditions: [.characterCount(2), .kanjiOnly]
        )
        #expect(result == ["構成"])
    }

    @Test
    func filtersKanjiCountsAndAlphanumericCandidates() {
        let filter = CandidateFilter()
        #expect(filter.filtered(["構成", "A構成", "abc"], conditions: [.kanjiCount(2)]) == ["構成", "A構成"])
        #expect(filter.filtered(["構成", "A構成", "abc"], conditions: [.containsAlphanumeric]) == ["A構成", "abc"])
    }

    @Test
    func filtersRadicalsComponentsAndStrokeCounts() {
        let filter = CandidateFilter(kanjiDatabase: database)
        let candidates = ["校正", "構成", "恒星"]
        #expect(filter.filtered(candidates, conditions: [.radical("木")]) == ["校正", "構成"])
        #expect(filter.filtered(candidates, conditions: [.component("交")]) == ["校正"])
        #expect(filter.filtered(candidates, conditions: [.strokeCount(9)]) == ["恒星"])
    }

    @Test
    func generatesAmbiguousChoicesBeforeApplyingAFilter() {
        let generator = CandidateFilterChoiceGenerator(aliasDictionaryText: """
        、
         灬
         丶
        れっか
         灬
        """)
        let labels = generator.choices(for: "、", activeConditions: []).map(\.label)
        #expect(labels.contains("構成要素: 灬"))
        #expect(labels.contains("構成要素: 丶"))
        #expect(labels.contains("「、」を含む"))
    }

    @Test
    func ranksSemanticResultsUsingOnlyCurrentCandidates() {
        let candidates = ["構成", "公正", "校正"]
        let result = CandidateFilter().filtered(
            candidates,
            conditions: [.semantic("文章")],
            semanticScorer: { _, candidate in
                ["校正": 0.91, "構成": 0.42, "公正": 0.12][candidate]
            }
        )
        #expect(result == ["校正", "構成", "公正"])
    }
}
