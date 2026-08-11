import Foundation

struct RomajiTypoScorer {
    static func cost(from source: String, to target: String) -> Double {
        let source = Array(source)
        let target = Array(target)
        guard !source.isEmpty else {
            return target.reduce(0) { $0 + insertionCost($1) }
        }
        guard !target.isEmpty else {
            return source.reduce(0) { $0 + deletionCost($1) }
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
            current[0] = previous[0] + deletionCost(source[sourceIndex - 1])
            for targetIndex in 1...target.count {
                let sourceCharacter = source[sourceIndex - 1]
                let targetCharacter = target[targetIndex - 1]
                current[targetIndex] = min(
                    previous[targetIndex]
                        + deletionCost(sourceCharacter),
                    current[targetIndex - 1]
                        + insertionCost(targetCharacter),
                    previous[targetIndex - 1]
                        + substitutionCost(
                            sourceCharacter,
                            targetCharacter
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
        vowels.contains(character) ? 0.35 : 0.8
    }

    private static func deletionCost(_ character: Character) -> Double {
        vowels.contains(character) ? 0.35 : 0.8
    }

    private static func substitutionCost(
        _ source: Character,
        _ target: Character
    ) -> Double {
        guard source != target else {
            return 0
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
