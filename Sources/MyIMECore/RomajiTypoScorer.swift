import Foundation

struct RomajiTypoScorer {
    static func cost(from source: String, to target: String) -> Double {
        cost(from: source, to: target, treatsHyphenAsVowel: false)
    }

    /// A wider, second-stage score for long inputs that already failed the
    /// ordinary typo lookup. A physical key at or beside the long-vowel key
    /// can stand in for a missing vowel, while all other edits retain the
    /// ordinary keyboard-aware costs.
    static func aggressiveCost(from source: String, to target: String) -> Double {
        cost(from: source, to: target, treatsHyphenAsVowel: true)
    }

    private static func cost(
        from source: String,
        to target: String,
        treatsHyphenAsVowel: Bool
    ) -> Double {
        let source = Array(source)
        let target = Array(target)
        guard !source.isEmpty else {
            return target.reduce(0) { $0 + insertionCost($1) }
        }
        guard !target.isEmpty else {
            return source.reduce(0) {
                $0 + deletionCost(
                    $1,
                    treatsHyphenAsVowel: treatsHyphenAsVowel
                )
            }
        }

        var previousPrevious = [Double](
            repeating: 0,
            count: target.count + 1
        )
        var previous = [Double](repeating: 0, count: target.count + 1)
        for index in 1...target.count {
            previous[index] = previous[index - 1]
                + insertionCost(target[index - 1])
        }

        for sourceIndex in 1...source.count {
            var current = [Double](repeating: 0, count: target.count + 1)
            current[0] = previous[0] + deletionCost(
                source[sourceIndex - 1],
                treatsHyphenAsVowel: treatsHyphenAsVowel
            )
            for targetIndex in 1...target.count {
                let sourceCharacter = source[sourceIndex - 1]
                let targetCharacter = target[targetIndex - 1]
                current[targetIndex] = min(
                    previous[targetIndex]
                        + deletionCost(
                            sourceCharacter,
                            treatsHyphenAsVowel: treatsHyphenAsVowel
                        ),
                    current[targetIndex - 1]
                        + insertionCost(targetCharacter),
                    previous[targetIndex - 1]
                        + substitutionCost(
                            sourceCharacter,
                            targetCharacter,
                            treatsHyphenAsVowel: treatsHyphenAsVowel
                        )
                )
                if sourceIndex > 1,
                   targetIndex > 1,
                   source[sourceIndex - 1] == target[targetIndex - 2],
                   source[sourceIndex - 2] == target[targetIndex - 1] {
                    current[targetIndex] = min(
                        current[targetIndex],
                        previousPrevious[targetIndex - 2] + 0.4
                    )
                }
            }
            previousPrevious = previous
            previous = current
        }
        return previous[target.count]
    }

    private static func insertionCost(_ character: Character) -> Double {
        return vowels.contains(character) ? 0.35 : 0.8
    }

    private static func deletionCost(
        _ character: Character,
        treatsHyphenAsVowel: Bool
    ) -> Double {
        if treatsHyphenAsVowel, character == "-" {
            return 0.35
        }
        return vowels.contains(character) ? 0.35 : 0.8
    }

    private static func substitutionCost(
        _ source: Character,
        _ target: Character,
        treatsHyphenAsVowel: Bool
    ) -> Double {
        guard source != target else {
            return 0
        }
        if treatsHyphenAsVowel {
            if source == "-" && vowels.contains(target)
                || target == "-" && vowels.contains(source) {
                return 0.2
            }
            if vowels.contains(target),
               let distance = RomajiKeyboardGeometry
                   .distanceFromLongVowelKey(source),
               distance <= 1.05 {
                return 0.2 + distance * 0.15
            }
        }
        if RomajiPhoneticRelation.differsByVoicing(source, target) {
            return 1.4
        }
        if let distance = RomajiKeyboardTypoGenerator.distance(
            from: source,
            to: target
        ), distance <= 1.25 {
            return 0.2 + distance * 0.15
        }
        if vowels.contains(source), vowels.contains(target) {
            return 0.45
        }
        return 1
    }

    private static let vowels: Set<Character> = Set("aeiou")
}

enum RomajiPhoneticRelation {
    /// Unvoiced consonants paired with the voiced ones that add dakuten,
    /// such as か→が or し→じ, so unrelated keys like g and h stay typos
    private static let voicedCounterparts: [Character: Set<Character>] = [
        "k": ["g"],
        "s": ["z", "j"],
        "t": ["d", "z", "j"],
        "c": ["j", "z"],
        "h": ["b"],
        "f": ["b", "v"],
        "p": ["b"]
    ]

    static func addsVoicing(
        from source: Character,
        to target: Character
    ) -> Bool {
        voicedCounterparts[source]?.contains(target) == true
    }

    static func differsByVoicing(
        _ source: Character,
        _ target: Character
    ) -> Bool {
        addsVoicing(from: source, to: target)
            || addsVoicing(from: target, to: source)
    }
}
