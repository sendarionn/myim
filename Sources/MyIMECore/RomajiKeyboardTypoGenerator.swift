import Foundation

public enum RomajiKeyboardTypoGenerator {
    private struct Position {
        let x: Double
        let y: Double
    }

    private static let positions: [Character: Position] = {
        var result: [Character: Position] = [:]
        let rows: [(String, Double)] = [
            ("qwertyuiop", 0),
            ("asdfghjkl", 0.25),
            ("zxcvbnm", 0.75)
        ]
        for (y, row) in rows.enumerated() {
            for (index, character) in row.0.enumerated() {
                result[character] = Position(
                    x: Double(index) + row.1,
                    y: Double(y)
                )
            }
        }
        return result
    }()

    public static func corrections(for input: String) -> [String] {
        let characters = Array(input.lowercased())
        var corrections: [String] = []
        for index in characters.indices {
            let source = characters[index]
            let neighbors = positions.keys.compactMap { target -> (
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
        var seenCandidates = Set<String>()
        var matches: [FuzzyConversionMatch] = []
        for correctedReading in corrections(for: input) {
            let canonical = RomajiCanonicalizer.canonicalInput(
                from: correctedReading
            )
            let candidates = dictionary.candidates(for: canonical).filter {
                seenCandidates.insert($0).inserted
            }
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
        guard let source = positions[source], let target = positions[target]
        else {
            return nil
        }
        return hypot(source.x - target.x, source.y - target.y)
    }
}
