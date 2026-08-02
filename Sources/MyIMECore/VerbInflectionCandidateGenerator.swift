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
        Self.candidates(for: reading) { baseReading in
            candidatesByReading[baseReading] ?? []
        }
    }

    public static func candidates(
        for reading: String,
        lookup: (String) -> [String]
    ) -> [String] {
        let normalized = RomanizedReadingNormalizer.dictionaryReading(
            from: reading
        )
        var result: [String] = []
        for rule in Self.rules(for: normalized) {
            let kanaReading = RomajiConverter().hiragana(from: rule.baseReading)
            let baseCandidates = lookup(rule.baseReading)
                + (kanaReading.map(lookup) ?? [])
            for candidate in baseCandidates {
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
            ("te", [("ru", "る")], "て"),
            ("ta", [("ru", "る")], "た"),
            ("nai", [("ru", "る")], "ない"),
            ("nakatta", [("ru", "る")], "なかった"),
            ("masu", [("ru", "る")], "ます"),
            ("mashita", [("ru", "る")], "ました"),
            ("masen", [("ru", "る")], "ません"),
            ("tai", [("ru", "る")], "たい"),
            ("tte", [("u", "う"), ("tsu", "つ"), ("ru", "る")], "って"),
            ("nde", [("mu", "む"), ("bu", "ぶ"), ("nu", "ぬ")], "んで"),
            ("ite", [("ku", "く")], "いて"),
            ("ide", [("gu", "ぐ")], "いで"),
            ("shite", [("su", "す")], "して"),
            ("shite", [("suru", "する")], "して"),
            ("tta", [("u", "う"), ("tsu", "つ"), ("ru", "る")], "った"),
            ("nda", [("mu", "む"), ("bu", "ぶ"), ("nu", "ぬ")], "んだ"),
            ("ita", [("ku", "く")], "いた"),
            ("ida", [("gu", "ぐ")], "いだ"),
            ("shita", [("su", "す")], "した"),
            ("shita", [("suru", "する")], "した"),
            ("shinai", [("suru", "する")], "しない"),
            ("shimasu", [("suru", "する")], "します"),
            ("shitai", [("suru", "する")], "したい"),
            ("wanai", [("u", "う")], "わない"),
            ("tanai", [("tsu", "つ")], "たない"),
            ("ranai", [("ru", "る")], "らない"),
            ("manai", [("mu", "む")], "まない"),
            ("banai", [("bu", "ぶ")], "ばない"),
            ("nanai", [("nu", "ぬ")], "なない"),
            ("kanai", [("ku", "く")], "かない"),
            ("ganai", [("gu", "ぐ")], "がない"),
            ("sanai", [("su", "す")], "さない"),
            ("imasu", [("u", "う")], "います"),
            ("chimasu", [("tsu", "つ")], "ちます"),
            ("rimasu", [("ru", "る")], "ります"),
            ("mimasu", [("mu", "む")], "みます"),
            ("bimasu", [("bu", "ぶ")], "びます"),
            ("nimasu", [("nu", "ぬ")], "にます"),
            ("kimasu", [("ku", "く")], "きます"),
            ("gimasu", [("gu", "ぐ")], "ぎます"),
            ("shimasu", [("su", "す")], "します")
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

        let kuruEndings: [String: String] = [
            "kite": "来て",
            "kita": "来た",
            "konai": "来ない",
            "kimasu": "来ます"
        ]
        if let ending = kuruEndings[reading] {
            result.append(
                Rule(
                    baseReading: "kuru",
                    baseEnding: "来る",
                    inflectedEnding: ending
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
