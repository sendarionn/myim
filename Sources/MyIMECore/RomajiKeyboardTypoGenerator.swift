import Foundation

public enum RomajiKeyboardTypoGenerator {
    private static let correctionTargets = Set("abcdefghijklmnopqrstuvwxyz")

    public static func corrections(for input: String) -> [String] {
        let characters = Array(input.lowercased())
        var corrections: [String] = []
        for index in characters.indices {
            let source = characters[index]
            // A symbol on or beside the long-vowel key stands for `-`; other
            // symbols and digits are only corrected to nearby letters
            if RomajiKeyboardGeometry.longVowelKeyNeighbors.contains(source) {
                var corrected = characters
                corrected[index] = "-"
                corrections.append(String(corrected))
            }
            let neighbors = correctionTargets.compactMap { target -> (
                Character,
                Double
            )? in
                guard source != target,
                      !RomajiPhoneticRelation.differsByVoicing(source, target),
                      let distance = distance(from: source, to: target),
                      distance <= 1.25 else {
                    return nil
                }
                return (target, distance)
            }.sorted {
                if $0.1 != $1.1 {
                    return $0.1 < $1.1
                }
                return $0.0 < $1.0
            }
            for (neighbor, _) in neighbors {
                var corrected = characters
                corrected[index] = neighbor
                corrections.append(String(corrected))
            }
        }
        return corrections
    }

    /// A reading reached by pressing a key beside the intended one at two
    /// or three places, such as `z=tp` for `a-to`
    public struct MultipleKeyCorrection: Equatable, Sendable {
        public let reading: String
        /// Sum of the keyboard-aware substitution costs
        public let cost: Double
        public let substitutions: Int
    }

    static let multipleKeyMaximumInputLength = 10
    /// Three keys are replaced only in short inputs, which keeps the
    /// readings tried for a longer input small
    static let threeKeyMaximumInputLength = 6

    /// Readings with two or three keys replaced by keys beside them on the
    /// US layout, cheapest first. Insertions, deletions, and transpositions
    /// stay with the ordinary search; single replacements are made by
    /// `corrections(for:)`
    public static func multipleKeyCorrections(
        for input: String,
        maximumSubstitutions: Int = 3,
        limit: Int = 4096
    ) -> [MultipleKeyCorrection] {
        let characters = Array(input.lowercased())
        guard (2...multipleKeyMaximumInputLength).contains(characters.count),
              maximumSubstitutions >= 2, limit > 0 else {
            return []
        }
        let maximumSubstitutions = characters.count
            > threeKeyMaximumInputLength
            ? min(maximumSubstitutions, 2)
            : maximumSubstitutions
        let options = characters.map(substitutionOptions)
        var results: [MultipleKeyCorrection] = []
        var current = characters

        func visit(from start: Int, substitutions: Int, cost: Double) {
            if substitutions >= 2 {
                results.append(MultipleKeyCorrection(
                    reading: String(current),
                    cost: cost,
                    substitutions: substitutions
                ))
            }
            guard substitutions < maximumSubstitutions else { return }
            for index in start..<characters.count {
                for (target, targetCost) in options[index] {
                    current[index] = target
                    visit(
                        from: index + 1,
                        substitutions: substitutions + 1,
                        cost: cost + targetCost
                    )
                }
                current[index] = characters[index]
            }
        }
        visit(from: 0, substitutions: 0, cost: 0)
        results.sort {
            if $0.cost != $1.cost { return $0.cost < $1.cost }
            return $0.reading < $1.reading
        }
        return Array(results.prefix(limit))
    }

    /// Keys beside `source` it may have been typed for, with the cost the
    /// typo scorer gives the replacement
    private static func substitutionOptions(
        _ source: Character
    ) -> [(Character, Double)] {
        var options: [(Character, Double)] = []
        if RomajiKeyboardGeometry.longVowelKeyNeighbors.contains(source),
           let distance = RomajiKeyboardGeometry.distanceFromLongVowelKey(
            source
           ) {
            options.append(("-", 0.2 + distance * 0.15))
        }
        for target in correctionTargets where target != source {
            guard !RomajiPhoneticRelation.differsByVoicing(source, target),
                  let distance = distance(from: source, to: target),
                  distance <= 1.25 else {
                continue
            }
            options.append((target, 0.2 + distance * 0.15))
        }
        return options.sorted {
            $0.1 != $1.1 ? $0.1 < $1.1 : $0.0 < $1.0
        }
    }

    /// Dictionary words reached by replacing two or three keys, tried
    /// cheapest first among readings that become kana as a whole
    public static func multipleKeyDictionaryMatches(
        for input: String,
        maximumMatches: Int = 4,
        excludingReadings: Set<String> = [],
        lookup: (String) -> [String]
    ) -> [FuzzyConversionMatch] {
        let converter = RomajiConverter()
        var seenCandidates = Set<String>()
        var matches: [FuzzyConversionMatch] = []
        for correction in multipleKeyCorrections(for: input) {
            guard !excludingReadings.contains(correction.reading),
                  let kana = converter.hiragana(from: correction.reading),
                  !kana.contains(where: { $0.isASCII && $0.isLetter }) else {
                continue
            }
            let candidates = RomajiCanonicalizer.dictionaryLookupInputs(
                from: correction.reading
            ).flatMap(lookup).filter { seenCandidates.insert($0).inserted }
            guard !candidates.isEmpty else { continue }
            matches.append(FuzzyConversionMatch(
                reading: correction.reading,
                candidates: candidates,
                distance: correction.substitutions
            ))
            if matches.count >= maximumMatches { break }
        }
        return matches
    }

    public static func dictionaryMatches(
        for input: String,
        dictionary: IndexedDictionaryEngine
    ) -> [FuzzyConversionMatch] {
        dictionaryMatches(for: input) {
            dictionary.candidates(for: $0)
        }
    }

    public static func dictionaryMatches(
        for input: String,
        lookup: @Sendable (String) -> [String]
    ) -> [FuzzyConversionMatch] {
        var seenCandidates = Set<String>()
        var matches: [FuzzyConversionMatch] = []
        for correctedReading in corrections(for: input) {
            let candidates = RomajiCanonicalizer.dictionaryLookupInputs(
                from: correctedReading
            ).flatMap(lookup).filter { seenCandidates.insert($0).inserted }
            guard !candidates.isEmpty else {
                continue
            }
            matches.append(
                FuzzyConversionMatch(
                    reading: correctedReading,
                    candidates: candidates,
                    distance: 1
                )
            )
        }
        return matches
    }

    static func distance(
        from source: Character,
        to target: Character
    ) -> Double? {
        RomajiKeyboardGeometry.typoDistance(from: source, to: target)
    }
}
