import Testing
@testable import MyIMECore

@Suite
struct SpecialConversionCandidateSourceTests {
    private let source = SpecialConversionCandidateSource()

    @Test
    func prioritizesCalculationResults() throws {
        let result = try #require(source.result(for: .init(
            input: "1+2=",
            javaScriptCandidates: ["1+2=", "3", "3"]
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
            javaScriptCandidates: ["script"]
        )))

        #expect(result.candidates.map(\.storageText)
            == UnitConversionCandidateGenerator.candidates(for: "100cm")
                + ["script"])
        #expect(result.candidates.last?.hasSource(.javaScriptExtension) == true)
        #expect(result.ordering == .selectionHistory)
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
    func preservesSymbolOrderWithoutRecencySorting() throws {
        let result = try #require(source.result(for: .init(input: "-")))

        #expect(result.candidates.map(\.storageText)
            == JapaneseSymbolConverter.candidates(for: "-"))
        #expect(result.ordering == .sourceOrder)
        #expect(result.showsSymbolTips)
        #expect(result.orderedCandidates(
            recencyRanks: [result.candidates.last!.storageText: 100]
        ) == result.candidates)
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
