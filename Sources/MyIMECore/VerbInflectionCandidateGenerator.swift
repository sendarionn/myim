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

    public func candidates(
        for reading: String,
        conjugations: VerbConjugationDictionary
    ) -> [String] {
        generatedCandidates(for: reading, conjugations: conjugations).map(\.text)
    }

    public func generatedCandidates(
        for reading: String,
        conjugations: VerbConjugationDictionary
    ) -> [GeneratedInflectionCandidate] {
        Self.generatedCandidates(for: reading, conjugations: conjugations) {
            baseReading in
            candidatesByReading[baseReading] ?? []
        }
    }

    public static func typoSearchEntries(
        from entries: [DictionaryEntry],
        conjugations: VerbConjugationDictionary
    ) -> [DictionaryEntry] {
        var generated: [DictionaryEntry] = []
        for entry in entries {
            let reading = RomajiCanonicalizer.canonicalInput(
                from: entry.input
            )
            var candidatesByReading: [String: [String]] = [:]
            var readingOrder: [String] = []
            for candidate in entry.candidates {
                for verb in conjugations.entries(for: reading)
                where verb.surface == candidate {
                    guard let inflected = VerbConjugationCandidateGenerator
                        .conjugate(verb, to: .te) else { continue }
                    if candidatesByReading[inflected.reading] == nil {
                        readingOrder.append(inflected.reading)
                    }
                    if candidatesByReading[inflected.reading]?.contains(
                        inflected.surface
                    ) != true {
                        candidatesByReading[
                            inflected.reading,
                            default: []
                        ].append(inflected.surface)
                    }
                }
            }
            for inflectedReading in readingOrder {
                generated.append(
                    DictionaryEntry(
                        reading: inflectedReading,
                        candidates: candidatesByReading[inflectedReading] ?? []
                    )
                )
            }
        }
        return generated
    }

    /// Every generated form must match a base form and class in the Mozc verb
    /// table
    public static func candidates(
        for reading: String,
        conjugations: VerbConjugationDictionary,
        lookup: (String) -> [String]
    ) -> [String] {
        generatedCandidates(
            for: reading,
            conjugations: conjugations,
            lookup: lookup
        ).map(\.text)
    }

    public static func generatedCandidates(
        for reading: String,
        conjugations: VerbConjugationDictionary,
        lookup: (String) -> [String]
    ) -> [GeneratedInflectionCandidate] {
        let normalized = RomajiCanonicalizer.canonicalInput(
            from: reading
        )
        var order: [String] = []
        var basesByCandidate: [String: Set<InflectionBaseIdentity>] = [:]
        for rule in Self.rules(for: normalized) {
            let kanaReading = RomajiConverter().hiragana(from: rule.baseReading)
            let baseCandidates = lookup(rule.baseReading)
                + (kanaReading.map(lookup) ?? [])
            for candidate in baseCandidates {
                guard candidate.hasSuffix(rule.baseEnding),
                      conjugations.allows(
                          reading: rule.baseReading,
                          surface: candidate,
                          classes: rule.classes
                      ) else {
                    continue
                }
                let inflected = String(
                    candidate.dropLast(rule.baseEnding.count)
                ) + rule.inflectedEnding
                let matchingEntries = conjugations.entries(
                    for: rule.baseReading
                ).filter {
                    $0.surface == candidate
                        && rule.classes.contains($0.conjugationClass)
                }
                guard !matchingEntries.isEmpty else { continue }
                if basesByCandidate[inflected] == nil {
                    order.append(inflected)
                }
                for entry in matchingEntries {
                    basesByCandidate[inflected, default: []].insert(
                        InflectionBaseIdentity(
                            kind: .verb,
                            reading: entry.reading,
                            surface: entry.surface,
                            inflectionType: entry.conjugationClass.rawValue
                        )
                    )
                }
            }
        }
        return order.map { candidate in
            GeneratedInflectionCandidate(
                text: candidate,
                bases: (basesByCandidate[candidate] ?? []).sorted {
                    $0.historyKey < $1.historyKey
                }
            )
        }
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

        let ichidanSuffixes: Set<String> = [
            "te", "ta", "nai", "nakatta", "masu", "mashita", "masen", "tai"
        ]
        let eitherClassSuffixes: Set<String> = [
            "saserareru", "rareru", "saseru", "reru"
        ]
        for group in suffixGroups where reading.hasSuffix(group.suffix) {
            let stem = String(reading.dropLast(group.suffix.count))
            for base in group.bases {
                let classes: Set<VerbConjugationClass>
                if base.reading == "suru" {
                    classes = [.suru]
                } else if ichidanSuffixes.contains(group.suffix) {
                    classes = [.ichidan]
                } else if eitherClassSuffixes.contains(group.suffix) {
                    classes = [.godan, .godanIku, .ichidan]
                } else {
                    classes = [.godan, .godanIku]
                }
                result.append(
                    Rule(
                        baseReading: stem + base.reading,
                        baseEnding: base.ending,
                        inflectedEnding: group.ending,
                        classes: classes
                    )
                )
            }
        }

        if reading == "itte" {
            result.append(
                Rule(
                    baseReading: "iku",
                    baseEnding: "く",
                    inflectedEnding: "って",
                    classes: [.godanIku]
                )
            )
        } else if reading == "itta" {
            result.append(
                Rule(
                    baseReading: "iku",
                    baseEnding: "く",
                    inflectedEnding: "った",
                    classes: [.godanIku]
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
                    inflectedEnding: ending,
                    classes: [.kuru]
                )
            )
        }

        return result
    }

    private struct Rule {
        let baseReading: String
        let baseEnding: String
        let inflectedEnding: String
        let classes: Set<VerbConjugationClass>
    }
}
