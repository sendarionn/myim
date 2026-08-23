import Foundation

public struct VerbInflectionCandidateGenerator: Sendable {
    private let candidatesByReading: [String: [String]]

    public init(entries: [DictionaryEntry]) {
        var values: [String: [String]] = [:]
        for entry in entries {
            let reading = RomajiCanonicalizer.canonicalInput(
                from: entry.input
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

    public static func typoSearchEntries(
        from entries: [DictionaryEntry]
    ) -> [DictionaryEntry] {
        let teFormRules: [(String, String, String, String)] = [
            ("suru", "する", "shite", "して"),
            ("tsu", "つ", "tte", "って"),
            ("mu", "む", "nde", "んで"),
            ("bu", "ぶ", "nde", "んで"),
            ("nu", "ぬ", "nde", "んで"),
            ("ku", "く", "ite", "いて"),
            ("gu", "ぐ", "ide", "いで"),
            ("su", "す", "shite", "して"),
            ("u", "う", "tte", "って"),
            ("ru", "る", "te", "て")
        ]
        var generated: [DictionaryEntry] = []
        for entry in entries {
            let reading = RomajiCanonicalizer.canonicalInput(
                from: entry.input
            )
            for rule in teFormRules
            where reading.hasSuffix(rule.0) {
                let candidates: [String] = entry.candidates.compactMap {
                    candidate -> String? in
                    guard candidate.hasSuffix(rule.1) else {
                        return nil
                    }
                    return String(candidate.dropLast(rule.1.count)) + rule.3
                }
                guard !candidates.isEmpty else {
                    continue
                }
                generated.append(
                    DictionaryEntry(
                        reading: String(reading.dropLast(rule.0.count))
                            + rule.2,
                        candidates: candidates
                    )
                )
                break
            }
        }
        return generated
    }

    public static func candidates(
        for reading: String,
        lookup: (String) -> [String]
    ) -> [String] {
        let normalized = RomajiCanonicalizer.canonicalInput(
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
            ("saserareru", [("ru", "る")], "させられる"),
            ("rareru", [("ru", "る")], "られる"),
            ("saseru", [("ru", "る"), ("su", "す")], "させる"),
            ("reru", [("ru", "る")], "れる"),
            ("aeru", [("au", "う")], "える"),
            ("teru", [("tsu", "つ")], "てる"),
            ("meru", [("mu", "む")], "める"),
            ("beru", [("bu", "ぶ")], "べる"),
            ("neru", [("nu", "ぬ")], "ねる"),
            ("keru", [("ku", "く")], "ける"),
            ("geru", [("gu", "ぐ")], "げる"),
            ("seru", [("su", "す")], "せる"),
            ("wareru", [("u", "う")], "われる"),
            ("tareru", [("tsu", "つ")], "たれる"),
            ("mareru", [("mu", "む")], "まれる"),
            ("bareru", [("bu", "ぶ")], "ばれる"),
            ("nareru", [("nu", "ぬ")], "なれる"),
            ("kareru", [("ku", "く")], "かれる"),
            ("gareru", [("gu", "ぐ")], "がれる"),
            ("sareru", [("su", "す")], "される"),
            ("waseru", [("u", "う")], "わせる"),
            ("taseru", [("tsu", "つ")], "たせる"),
            ("raseru", [("ru", "る")], "らせる"),
            ("maseru", [("mu", "む")], "ませる"),
            ("baseru", [("bu", "ぶ")], "ばせる"),
            ("naseru", [("nu", "ぬ")], "なせる"),
            ("kaseru", [("ku", "く")], "かせる"),
            ("gaseru", [("gu", "ぐ")], "がせる"),
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
