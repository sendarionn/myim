import Foundation

public enum SpecialConversionCandidateOrdering: Equatable, Sendable {
    case sourceOrder
    case selectionHistory
    /// The defined first candidate, such as `。` for `.`, stays first and
    /// the rest follow the selection history
    case selectionHistoryAfterFirst
}

public struct SpecialConversionCandidateContext: Equatable, Sendable {
    public let input: String
    public let javaScriptCandidates: [JavaScriptExtensionCandidate]
    public let calculationHistoryCandidates: [String]
    public let postalAddressCandidates: [String]

    public init(
        input: String,
        javaScriptCandidates: [JavaScriptExtensionCandidate] = [],
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
        switch ordering {
        case .sourceOrder:
            return candidates
        case .selectionHistory:
            return CandidateRecencyOrderer.orderedIndices(
                candidates.map(\.storageText),
                ranks: recencyRanks
            ).map { candidates[$0] }
        case .selectionHistoryAfterFirst:
            guard let first = candidates.first else { return [] }
            let rest = Array(candidates.dropFirst())
            return [first] + CandidateRecencyOrderer.orderedIndices(
                rest.map(\.storageText),
                ranks: recencyRanks
            ).map { rest[$0] }
        }
    }
}

public struct SpecialConversionCandidateSource: Sendable {
    public init() {}

    public func result(
        for context: SpecialConversionCandidateContext
    ) -> SpecialConversionCandidateResult? {
        let input = context.input
        let javaScript = context.javaScriptCandidates.map {
            Candidate(
                storageText: $0.value,
                source: $0.kind == .dynamicDateTime
                    ? .dateTime
                    : .javaScriptExtension,
                reading: input
            )
        }
        if input.trimmingCharacters(in: .whitespaces).hasSuffix("="),
           !context.javaScriptCandidates.isEmpty {
            return SpecialConversionCandidateResult(
                candidates: makeCandidates(
                    CalculationCandidateSet.visible(
                        generatedCandidates: context.javaScriptCandidates.map(\.value),
                        input: input
                    ),
                    source: { _ in .javaScriptExtension },
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
                    source: { _ in .selectionHistory },
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
                    source: { _ in .specialConversion },
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
                    source: { _ in .specialConversion },
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
                    source: { _ in .specialConversion },
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
                    source: { _ in .specialConversion },
                    reading: input
                ) + javaScript,
                ordering: .selectionHistoryAfterFirst,
                showsSymbolTips: true
            )
        }

        return nil
    }

    private func makeCandidates(
        _ values: [String],
        source: (String) -> CandidateSourceKind,
        reading: String
    ) -> [Candidate] {
        values.map {
            Candidate(
                storageText: $0,
                source: source($0),
                reading: reading
            )
        }
    }
}
