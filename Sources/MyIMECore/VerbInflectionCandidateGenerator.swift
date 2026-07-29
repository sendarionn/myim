import Foundation

public struct VerbInflectionCandidateGenerator: Sendable {
    private let candidatesByReading: [String: [String]]

    public init(entries: [DictionaryEntry]) {
        var values: [String: [String]] = [:]
        for entry in entries {
            let reading = RomanizedReadingNormalizer.dictionaryReading(
                from: entry.reading
            )
            values[reading, default: []].append(contentsOf: entry.candidates)
        }
        candidatesByReading = values
    }

    public func candidates(for reading: String) -> [String] {
        let normalized = RomanizedReadingNormalizer.dictionaryReading(
            from: reading
        )
        var result: [String] = []
        for rule in Self.rules(for: normalized) {
            for candidate in candidatesByReading[rule.baseReading] ?? [] {
                guard candidate.hasSuffix(rule.baseEnding) else {
                    continue
                }
                let inflected = String(
                    candidate.dropLast(rule.baseEnding.count)
                ) + rule.inflectedEnding
                if !result.contains(inflected) {
                    result.append(inflected)
                }
            }
        }
        return result
    }

    private static func rules(for reading: String) -> [Rule] {
        var result: [Rule] = []
        let suffixGroups: [
            (
                suffix: String,
                bases: [(reading: String, ending: String)],
                ending: String
            )
        ] = [
            ("tte", [("u", "う"), ("tsu", "つ"), ("ru", "る")], "って"),
            ("nde", [("mu", "む"), ("bu", "ぶ"), ("nu", "ぬ")], "んで"),
            ("ite", [("ku", "く")], "いて"),
            ("ide", [("gu", "ぐ")], "いで"),
            ("shite", [("su", "す")], "して"),
            ("tta", [("u", "う"), ("tsu", "つ"), ("ru", "る")], "った"),
            ("nda", [("mu", "む"), ("bu", "ぶ"), ("nu", "ぬ")], "んだ"),
            ("ita", [("ku", "く")], "いた"),
            ("ida", [("gu", "ぐ")], "いだ"),
            ("shita", [("su", "す")], "した")
        ]

        for group in suffixGroups where reading.hasSuffix(group.suffix) {
            let stem = String(reading.dropLast(group.suffix.count))
            for base in group.bases {
                result.append(
                    Rule(
                        baseReading: stem + base.reading,
                        baseEnding: base.ending,
                        inflectedEnding: group.ending
                    )
                )
            }
        }

        if reading == "itte" {
            result.append(
                Rule(
                    baseReading: "iku",
                    baseEnding: "く",
                    inflectedEnding: "って"
                )
            )
        } else if reading == "itta" {
            result.append(
                Rule(
                    baseReading: "iku",
                    baseEnding: "く",
                    inflectedEnding: "った"
                )
            )
        }

        return result
    }

    private struct Rule {
        let baseReading: String
        let baseEnding: String
        let inflectedEnding: String
    }
}
