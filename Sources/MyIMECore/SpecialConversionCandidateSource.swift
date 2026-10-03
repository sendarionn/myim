import Foundation

public enum SpecialConversionCandidateOrdering: Equatable, Sendable {
    case sourceOrder
    case selectionHistory
}

public struct SpecialConversionCandidateContext: Equatable, Sendable {
    public let input: String
    public let javaScriptCandidates: [String]
    public let calculationHistoryCandidates: [String]
    public let postalAddressCandidates: [String]

    public init(
        input: String,
        javaScriptCandidates: [String] = [],
        calculationHistoryCandidates: [String] = [],
        postalAddressCandidates: [String] = []
    ) {
        self.input = input
        self.javaScriptCandidates = javaScriptCandidates
        self.calculationHistoryCandidates = calculationHistoryCandidates
        self.postalAddressCandidates = postalAddressCandidates
    }
}

public struct SpecialConversionCandidateResult: Equatable, Sendable {
    public let candidates: [Candidate]
    public let ordering: SpecialConversionCandidateOrdering
    public let showsSymbolTips: Bool

    public init(
        candidates: [Candidate],
        ordering: SpecialConversionCandidateOrdering,
        showsSymbolTips: Bool = false
    ) {
        self.candidates = candidates
        self.ordering = ordering
        self.showsSymbolTips = showsSymbolTips
    }

    public func orderedCandidates(
        recencyRanks: [String: Int]
    ) -> [Candidate] {
        guard ordering == .selectionHistory else { return candidates }
        return CandidateRecencyOrderer.orderedIndices(
            candidates.map(\.storageText),
            ranks: recencyRanks
        ).map { candidates[$0] }
    }
}

public struct SpecialConversionCandidateSource: Sendable {
    public init() {}

    public func result(
        for context: SpecialConversionCandidateContext
    ) -> SpecialConversionCandidateResult? {
        let input = context.input
        let javaScript = makeCandidates(
            context.javaScriptCandidates,
            source: .javaScriptExtension,
            reading: input
        )
        if input.trimmingCharacters(in: .whitespaces).hasSuffix("="),
           !context.javaScriptCandidates.isEmpty {
            return SpecialConversionCandidateResult(
                candidates: makeCandidates(
                    CalculationCandidateSet.visible(
                        generatedCandidates: context.javaScriptCandidates,
                        input: input
                    ),
                    source: .javaScriptExtension,
                    reading: input
                ),
                ordering: .selectionHistory
            )
        }

        let calculationHistory = CalculationInputHistory
            .completionCandidates(
                input: input,
                historyCandidates: context.calculationHistoryCandidates
            )
        if !calculationHistory.isEmpty {
            return SpecialConversionCandidateResult(
                candidates: makeCandidates(
                    calculationHistory,
                    source: .selectionHistory,
                    reading: input
                ),
                ordering: .selectionHistory
            )
        }

        let unitConversion = UnitConversionCandidateGenerator.candidates(
            for: input
        )
        if !unitConversion.isEmpty {
            return SpecialConversionCandidateResult(
                candidates: makeCandidates(
                    unitConversion,
                    source: .specialConversion,
                    reading: input
                ) + javaScript,
                ordering: .selectionHistory
            )
        }

        let groupedNumbers = NumberGroupingCandidateGenerator.candidates(
            for: input
        )
        let numericUnits = JapaneseNumericUnitCandidateGenerator.candidates(
            for: input
        )
        if !groupedNumbers.isEmpty || !numericUnits.isEmpty {
            let numericFormats = groupedNumbers
                + JapaneseNumberConverter.kanjiCandidates(for: input)
                + numericUnits
                + context.postalAddressCandidates
            return SpecialConversionCandidateResult(
                candidates: makeCandidates(
                    numericFormats,
                    source: .specialConversion,
                    reading: input
                ) + javaScript,
                ordering: .selectionHistory
            )
        }

        let japaneseNumbers = JapaneseNumberConverter.candidates(for: input)
        if !japaneseNumbers.isEmpty {
            return SpecialConversionCandidateResult(
                candidates: makeCandidates(
                    japaneseNumbers,
                    source: .specialConversion,
                    reading: input
                ) + javaScript,
                ordering: .selectionHistory
            )
        }

        let symbols = JapaneseSymbolConverter.candidates(for: input)
        if !symbols.isEmpty {
            return SpecialConversionCandidateResult(
                candidates: makeCandidates(
                    symbols,
                    source: .specialConversion,
                    reading: input
                ) + javaScript,
                ordering: .sourceOrder,
                showsSymbolTips: true
            )
        }

        return nil
    }

    private func makeCandidates(
        _ values: [String],
        source: CandidateSourceKind,
        reading: String
    ) -> [Candidate] {
        values.map {
            Candidate(
                storageText: $0,
                source: source,
                reading: reading
            )
        }
    }
}
