import Foundation

public enum RomajiKeyboardTypoGenerator {
    private static let correctionTargets = Set("abcdefghijklmnopqrstuvwxyz")

    public static func corrections(for input: String) -> [String] {
        let characters = Array(input.lowercased())
        var corrections: [String] = []
        for index in characters.indices {
            let source = characters[index]
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
        RomajiKeyboardGeometry.minimumDistance(from: source, to: target)
    }
}
