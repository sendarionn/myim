import Foundation
import Testing
@testable import MyIMECore

@Suite
struct CandidateFilterTests {
    @Test
    func usesFilterInputInsteadOfOriginalConversionForLearning() {
        var history = CandidateSelectionHistory()
        let reading = CandidateFilterLearning.reading(for: "1")
        if let reading {
            history.record("1", reading: reading)
        }

        #expect(history.candidates(for: ["1"]) == ["1"])
        #expect(history.candidates(for: ["maru"]).isEmpty)
        #expect(CandidateFilterLearning.reading(for: "  ") == nil)
    }

    private let database = KanjiFilterDatabase(values: [
        "校": KanjiFilterAttributes(radical: "木", strokeCount: 10, components: ["木", "交"]),
        "構": KanjiFilterAttributes(radical: "木", strokeCount: 14, components: ["木"]),
        "星": KanjiFilterAttributes(radical: "日", strokeCount: 9, components: ["日", "生"])
    ])

    @Test
    func confirmsUnconvertedFilterInputDirectly() {
        #expect(CandidateFilterInputConfirmationPolicy.canConfirmDirectly(
            input: "2",
            queryVariants: ["2"]
        ))
        #expect(CandidateFilterInputConfirmationPolicy.canConfirmDirectly(
            input: "木",
            queryVariants: ["木"]
        ))
    }

    @Test
    func requiresSelectionWhenFilterInputHasConversionCandidates() {
        #expect(!CandidateFilterInputConfirmationPolicy.canConfirmDirectly(
            input: "ki",
            queryVariants: ["ki", "き", "キ", "木"]
        ))
        #expect(!CandidateFilterInputConfirmationPolicy.canConfirmDirectly(
            input: "",
            queryVariants: [""]
        ))
    }

    @Test
    func mapsArrowEventsFromKeyAndCommandPaths() {
        #expect(CandidateFilterArrowNavigation.offset(forKeyCode: 124) == 1)
        #expect(CandidateFilterArrowNavigation.offset(forKeyCode: 125) == 1)
        #expect(CandidateFilterArrowNavigation.offset(forKeyCode: 123) == -1)
        #expect(CandidateFilterArrowNavigation.offset(forKeyCode: 126) == -1)
        #expect(CandidateFilterArrowNavigation.offset(forCommand: "moveDown:") == 1)
        #expect(CandidateFilterArrowNavigation.offset(forCommand: "moveUp:") == -1)
        #expect(CandidateFilterArrowNavigation.offset(forCommand: "deleteBackward:") == nil)
    }

    @Test
    func placesFilterPanelBesideCandidatePanelWithinTheScreen() {
        let visibleFrame = CandidateFilterPanelRect(
            x: 0, y: 0, width: 800, height: 600
        )
        #expect(CandidateFilterPanelPlacement.origin(
            beside: CandidateFilterPanelRect(
                x: 100, y: 200, width: 200, height: 160
            ),
            panelWidth: 180,
            panelHeight: 120,
            visibleFrame: visibleFrame
        ) == CandidateFilterPanelPoint(x: 308, y: 240))
        #expect(CandidateFilterPanelPlacement.origin(
            beside: CandidateFilterPanelRect(
                x: 650, y: 200, width: 140, height: 160
            ),
            panelWidth: 180,
            panelHeight: 120,
            visibleFrame: visibleFrame
        ) == CandidateFilterPanelPoint(x: 462, y: 240))
    }

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
        #expect(filter.filtered(candidates, conditions: [.contains("木")]) == ["校正", "構成"])
        #expect(filter.filtered(candidates, conditions: [.contains("交")]) == ["校正"])
        #expect(filter.filtered(candidates, conditions: [.strokeCount(9)]) == ["恒星"])
    }

    @Test
    func searchesCharactersRadicalsAndIDSComponentsAsOneElement() {
        let filter = CandidateFilter(kanjiDatabase: KanjiFilterDatabase(values: [
            "校": KanjiFilterAttributes(radical: "木", components: ["交"]),
            "想": KanjiFilterAttributes(radical: "心", components: ["相", "木", "目"])
        ]))

        #expect(filter.filtered(
            ["木", "校", "想", "心"],
            conditions: [.contains("木")]
        ) == ["木", "校", "想"])
    }

    @Test
    func normalizesCommonRadicalVariants() {
        let filter = CandidateFilter(kanjiDatabase: KanjiFilterDatabase(values: [
            "海": KanjiFilterAttributes(radical: "水"),
            "休": KanjiFilterAttributes(radical: "人"),
            "持": KanjiFilterAttributes(radical: "手"),
            "情": KanjiFilterAttributes(radical: "心"),
            "熱": KanjiFilterAttributes(radical: "火"),
            "花": KanjiFilterAttributes(radical: "艸")
        ]))

        #expect(filter.filtered(["海"], conditions: [.contains("氵")]) == ["海"])
        #expect(filter.filtered(["休"], conditions: [.contains("亻")]) == ["休"])
        #expect(filter.filtered(["持"], conditions: [.contains("扌")]) == ["持"])
        #expect(filter.filtered(["情"], conditions: [.contains("忄")]) == ["情"])
        #expect(filter.filtered(["熱"], conditions: [.contains("灬")]) == ["熱"])
        #expect(filter.filtered(["花"], conditions: [.contains("艹")]) == ["花"])
    }

    @Test
    func filtersRadicalsUsingTheBundledUnihanData() throws {
        let resourceDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyIMEMacOS/Resources")
        let text = try String(
            contentsOf: resourceDirectory
                .appendingPathComponent("kanji-filter-data.tsv"),
            encoding: .utf8
        )
        let filter = CandidateFilter(
            kanjiDatabase: KanjiFilterDatabase(text: text)
        )

        #expect(filter.filtered(
            ["海", "池", "河", "洋", "木"],
            conditions: [.contains("氵")]
        ) == ["海", "池", "河", "洋"])
        #expect(filter.filtered(
            ["休", "体", "作", "木"],
            conditions: [.contains("亻")]
        ) == ["休", "体", "作"])
        #expect(filter.filtered(
            ["打", "持", "情"],
            conditions: [.contains("扌")]
        ) == ["打", "持"])
        #expect(filter.filtered(
            ["性", "情", "持"],
            conditions: [.contains("忄")]
        ) == ["性", "情"])

        let aliases = try String(
            contentsOf: resourceDirectory
                .appendingPathComponent("candidate-filter-aliases.tsv"),
            encoding: .utf8
        )
        let labels = CandidateFilterChoiceGenerator(
            aliasDictionaryText: aliases
        ).choices(for: "さんずい", activeConditions: []).map(\.label)
        #expect(labels.contains("「氵」を含む"))
        #expect(!labels.contains { $0.hasPrefix("部首:") })
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
        #expect(labels.contains("「灬」を含む"))
        #expect(labels.contains("「丶」を含む"))
        #expect(labels.filter { $0 == "「灬」を含む" }.count == 1)
        #expect(labels.contains("「、」を含む"))
    }

    @Test
    func importsAndRecursivelyExpandsOptionalIDSData() {
        let database = KanjiFilterDatabase(
            text: "想\t心\t13\t\n",
            supplementalIDSTexts: ["""
            # CJKVI and CHISE compatible columns
            U+4F11\t休\t⿰亻木
            U+76F8\t相\t⿰木目
            U+60F3\t想\t⿱相心
            """]
        )
        let filter = CandidateFilter(kanjiDatabase: database)

        #expect(filter.filtered(["休", "想"], conditions: [.contains("亻")]) == ["休"])
        #expect(filter.filtered(["休", "想"], conditions: [.contains("木")]) == ["休", "想"])
        #expect(filter.filtered(["休", "想"], conditions: [.contains("目")]) == ["想"])
    }

    @Test
    func ignoresEntitiesAndRegionTagsInIDSData() {
        let components = KanjiIDSComponentParser.components(from: [
            "U+8A9E\t語\t⿰言&CDP-1234; (J) 吾"
        ])

        #expect(components["語"] == Set(["言", "吾"]))
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
