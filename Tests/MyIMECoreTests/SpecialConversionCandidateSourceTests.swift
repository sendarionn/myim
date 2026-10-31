import Testing
@testable import MyIMECore

@Suite
struct SpecialConversionCandidateSourceTests {
    private let source = SpecialConversionCandidateSource()

    @Test
    func prioritizesCalculationResults() throws {
        let result = try #require(source.result(for: .init(
            input: "1+2=",
            javaScriptCandidates: [
                .init(value: "1+2="),
                .init(value: "3"),
                .init(value: "3")
            ]
        )))

        #expect(result.candidates.map(\.storageText) == ["3"])
        #expect(result.candidates.allSatisfy {
            $0.hasSource(.javaScriptExtension)
        })
        #expect(result.ordering == .selectionHistory)
    }

    @Test
    func restoresCalculationExpressionsFromHistory() throws {
        let result = try #require(source.result(for: .init(
            input: "1+",
            calculationHistoryCandidates: ["1+2=", "2+2="]
        )))

        #expect(result.candidates.map(\.storageText) == ["1+2="])
        #expect(result.candidates[0].hasSource(.selectionHistory))
    }

    @Test
    func keepsSpecialSourcePrecedence() throws {
        let result = try #require(source.result(for: .init(
            input: "100cm",
            javaScriptCandidates: [.init(value: "script")]
        )))

        #expect(result.candidates.map(\.storageText)
            == UnitConversionCandidateGenerator.candidates(for: "100cm")
                + ["script"])
        #expect(result.candidates.last?.hasSource(.javaScriptExtension) == true)
        #expect(result.ordering == .selectionHistory)
    }

    @Test
    func keepsDynamicDateTimeOriginWhenMergedWithSpecialCandidates() throws {
        let result = try #require(source.result(for: .init(
            input: "1000",
            javaScriptCandidates: [
                .init(
                    value: "20261031",
                    kind: .dynamicDateTime,
                    preferenceID: "dynamic_date:kyou:YYYYMMDD"
                )
            ]
        )))
        let dynamic = try #require(result.candidates.first {
            $0.storageText == "20261031"
        })

        #expect(dynamic.hasSource(.dateTime))
        #expect(!dynamic.allowsSelectionHistory)
        #expect(
            dynamic.dynamicPreferenceID
                == "dynamic_date:kyou:YYYYMMDD"
        )
    }

    @Test
    func addsPostalCandidatesOnlyToNumericFormats() throws {
        let result = try #require(source.result(for: .init(
            input: "1000",
            postalAddressCandidates: ["住所"]
        )))

        #expect(result.candidates.map(\.storageText).contains("1,000"))
        #expect(result.candidates.map(\.storageText).contains("住所"))
    }

    @Test
    func keepsTheFirstSymbolAndOrdersTheRestByRecency() throws {
        let result = try #require(source.result(for: .init(input: "-")))
        let defined = JapaneseSymbolConverter.candidates(for: "-")
        let last = try #require(defined.last)

        #expect(result.candidates.map(\.storageText) == defined)
        #expect(result.ordering == .selectionHistoryAfterFirst)
        #expect(result.showsSymbolTips)
        #expect(texts(result, ranks: [last: 100])
            == [defined[0], last] + defined.dropFirst().dropLast())
    }

    @Test
    func selectingTheFirstSymbolLeavesTheOrderUnchanged() throws {
        let result = try #require(source.result(for: .init(input: "-")))
        let defined = JapaneseSymbolConverter.candidates(for: "-")

        #expect(texts(result, ranks: [:]) == defined)
        #expect(texts(result, ranks: [defined[0]: 200]) == defined)
        #expect(texts(result, ranks: [defined[0]: 200, defined[2]: 100])
            == [defined[0], defined[2], defined[1]] + defined.dropFirst(3))
    }

    @Test
    func repeatedlyUsedSymbolNeverTakesTheFirstPlace() throws {
        let result = try #require(source.result(for: .init(input: "-")))
        let defined = JapaneseSymbolConverter.candidates(for: "-")
        var history = CandidateSelectionHistory()
        for _ in 0..<5 {
            history.record(defined[2], reading: "-")
        }
        history.record(defined[1], reading: "-")

        let ordered = texts(result, ranks: history.ranks(for: "-"))

        #expect(ordered.first == defined[0])
        #expect(Array(ordered.prefix(3)) == [defined[0], defined[1], defined[2]])
        #expect(Set(ordered) == Set(defined))
        #expect(ordered.count == defined.count)
    }

    @Test
    func symbolHistoryOfAnotherInputIsNotApplied() throws {
        let result = try #require(source.result(for: .init(input: "-")))
        let defined = JapaneseSymbolConverter.candidates(for: "-")
        var history = CandidateSelectionHistory()
        history.record(defined[2], reading: "~")

        #expect(texts(result, ranks: history.ranks(for: "-")) == defined)
    }

    @Test
    func singleSymbolCandidateIsKept() {
        let result = SpecialConversionCandidateResult(
            candidates: [Candidate(storageText: "。")],
            ordering: .selectionHistoryAfterFirst
        )

        #expect(texts(result, ranks: ["。": 1]) == ["。"])
        #expect(SpecialConversionCandidateResult(
            candidates: [],
            ordering: .selectionHistoryAfterFirst
        ).orderedCandidates(recencyRanks: [:]).isEmpty)
    }

    private func texts(
        _ result: SpecialConversionCandidateResult,
        ranks: [String: Int]
    ) -> [String] {
        result.orderedCandidates(recencyRanks: ranks).map(\.storageText)
    }

    @Test
    func appliesRecencyOnlyWhenRequested() throws {
        let result = try #require(source.result(for: .init(
            input: "100cm"
        )))
        let last = try #require(result.candidates.last)

        #expect(result.orderedCandidates(
            recencyRanks: [last.storageText: 100]
        ).first?.storageText == last.storageText)
    }

    @Test
    func ignoresOrdinaryConversionInput() {
        #expect(source.result(for: .init(input: "kouho")) == nil)
    }
}
