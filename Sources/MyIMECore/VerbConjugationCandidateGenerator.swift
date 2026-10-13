/// Verb classes from the Mozc base forms in `mozc-verb-classes.tsv`
public enum VerbConjugationClass: String, Sendable {
    case godan
    case godanIku = "godan-iku"
    case ichidan
    case suru
    case zuru
    case kuru
}

public enum VerbConjugationForm: Sendable, CaseIterable {
    /// 連用形 such as 知り in 知りたい
    case continuative
    /// テ形 such as 分かって in 分かっている
    case te
    /// タ形 such as 分かった
    case past
    /// 未然形 such as 分から in 分からない
    case negative
    /// 仮定形 such as 分かれ in 分かれば
    case conditional
    /// 終止形 such as 分かる in 分かるので
    case terminal
}

public struct VerbConjugationDictionary: Sendable {
    public struct Entry: Equatable, Sendable {
        public let reading: String
        public let surface: String
        public let conjugationClass: VerbConjugationClass
        /// Mozc cost of the base form; lower is more common
        public let cost: Int
    }

    private let entriesByReading: [String: [Entry]]

    public init(text: String = "") {
        var entries: [String: [Entry]] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let columns = line.split(separator: "\t")
            guard columns.count == 4,
                  let conjugationClass = VerbConjugationClass(
                    rawValue: String(columns[2])
                  ),
                  let cost = Int(columns[3]) else { continue }
            let reading = String(columns[0])
            entries[reading, default: []].append(Entry(
                reading: reading,
                surface: String(columns[1]),
                conjugationClass: conjugationClass,
                cost: cost
            ))
        }
        entriesByReading = entries
    }

    public func entries(for reading: String) -> [Entry] {
        entriesByReading[reading] ?? []
    }

    /// Whether the Mozc verb table contains this reading, surface, and class
    public func allows(
        reading: String,
        surface: String,
        classes: Set<VerbConjugationClass>
    ) -> Bool {
        entries(for: reading).contains {
            $0.surface == surface
                && classes.contains($0.conjugationClass)
        }
    }
}

/// Converts readings such as `wakatteiru` by splitting a following
/// expression, reversing the verb form to its base reading, and keeping only
/// base forms whose dictionary class produces the same form
///
/// Verbs written in plain kana are left to the automatic kana candidates
public struct VerbConjugationCandidateGenerator: Sendable {
    private struct FollowingExpression: Sendable {
        let requiredVerbForm: VerbConjugationForm
        let readingSuffix: String
        let surfaceSuffix: String
        /// Bare 連用形 and 終止形 of a dictionary verb are dictionary words
        /// themselves, so only verbs derived here are generated bare
        let derivedOnly: Bool

        init(
            _ readingSuffix: String,
            _ surfaceSuffix: String,
            requiring requiredVerbForm: VerbConjugationForm,
            derivedOnly: Bool = false
        ) {
            self.requiredVerbForm = requiredVerbForm
            self.readingSuffix = readingSuffix
            self.surfaceSuffix = surfaceSuffix
            self.derivedOnly = derivedOnly
        }

        var isBareContinuative: Bool {
            readingSuffix.isEmpty && requiredVerbForm == .continuative
        }
    }

    /// 希望を表す「たい」と、その形容詞型の活用
    private static let desireInflections: [FollowingExpression] = [
        FollowingExpression("takunakatta", "たくなかった", requiring: .continuative),
        FollowingExpression("takereba", "たければ", requiring: .continuative),
        FollowingExpression("takunai", "たくない", requiring: .continuative),
        FollowingExpression("takatta", "たかった", requiring: .continuative),
        FollowingExpression("takute", "たくて", requiring: .continuative),
        FollowingExpression("tai", "たい", requiring: .continuative)
    ]

    /// 「たい」の活用ではなく「たく + なる」で構成される表現
    private static let desireChanges: [FollowingExpression] = [
        FollowingExpression("takunaranai", "たくならない", requiring: .continuative),
        FollowingExpression("takunatta", "たくなった", requiring: .continuative),
        FollowingExpression("takunaru", "たくなる", requiring: .continuative)
    ]

    private static let otherFollowings: [FollowingExpression] = [
        FollowingExpression("", "", requiring: .continuative, derivedOnly: true),
        FollowingExpression("", "", requiring: .terminal, derivedOnly: true),
        FollowingExpression("", "", requiring: .te),
        FollowingExpression("", "", requiring: .past),
        FollowingExpression("masendeshita", "ませんでした", requiring: .continuative),
        FollowingExpression("masu", "ます", requiring: .continuative),
        FollowingExpression("mashita", "ました", requiring: .continuative),
        FollowingExpression("masen", "ません", requiring: .continuative),
        FollowingExpression("nagara", "ながら", requiring: .continuative),
        FollowingExpression("nai", "ない", requiring: .negative),
        FollowingExpression("nakatta", "なかった", requiring: .negative),
        FollowingExpression("nakereba", "なければ", requiring: .negative),
        FollowingExpression("nakute", "なくて", requiring: .negative),
        FollowingExpression("ba", "ば", requiring: .conditional),
        FollowingExpression("ra", "ら", requiring: .past),
        FollowingExpression("ri", "り", requiring: .past),
        FollowingExpression("na", "な", requiring: .terminal),
        FollowingExpression("node", "ので", requiring: .terminal),
        FollowingExpression("kara", "から", requiring: .terminal),
        FollowingExpression("kedo", "けど", requiring: .terminal),
        FollowingExpression("keredo", "けれど", requiring: .terminal)
    ]

    /// Expressions joined to the テ形, including the auxiliary verbs いる,
    /// おく, しまう, and みる in their common forms
    private static let teFollowings: [FollowingExpression] = [
        ("itemo", "いても"), ("iru", "いる"), ("ita", "いた"),
        ("inai", "いない"), ("imasu", "います"),
        ("oku", "おく"), ("oita", "おいた"), ("oite", "おいて"),
        ("shimau", "しまう"), ("shimatta", "しまった"),
        ("shimatte", "しまって"),
        ("miru", "みる"), ("mita", "みた"), ("mite", "みて"),
        ("mo", "も"), ("kara", "から")
    ].map { FollowingExpression($0.0, $0.1, requiring: .te) }

    private static let maximumBareContinuativeCandidates = 1

    private static let followingExpressions =
        desireChanges + desireInflections + otherFollowings + teFollowings

    private static let voiceReverseRules: [VoiceReverseRule] = {
        var rules: [VoiceReverseRule] = []
        func appendRules(
            conjugationClass: VerbConjugationClass,
            derivedStem: String,
            baseEnding: String
        ) {
            rules.append(VoiceReverseRule(
                .causativePassive,
                derivedStem + "serareru",
                baseEnding,
                conjugationClass
            ))
            rules.append(VoiceReverseRule(
                .causative,
                derivedStem + "seru",
                baseEnding,
                conjugationClass
            ))
            rules.append(VoiceReverseRule(
                .passive,
                derivedStem + "reru",
                baseEnding,
                conjugationClass
            ))
        }
        for row in GodanRow.rows {
            appendRules(
                conjugationClass: .godan,
                derivedStem: row.negative.0,
                baseEnding: row.reading
            )
        }
        appendRules(
            conjugationClass: .godanIku,
            derivedStem: GodanRow.iku.negative.0,
            baseEnding: GodanRow.iku.reading
        )
        // 呼ばされる is the short 呼ばせられる; す verbs keep the long form
        let shortCausativeRows = GodanRow.rows.map { ($0, VerbConjugationClass.godan) }
            + [(GodanRow.iku, .godanIku)]
        for (row, conjugationClass) in shortCausativeRows
        where row.reading != "su" {
            rules.append(VoiceReverseRule(
                .shortCausativePassive,
                row.negative.0 + "sareru",
                row.reading,
                conjugationClass
            ))
        }
        rules.append(contentsOf: [
            VoiceReverseRule(.causativePassive, "saserareru", "ru", .ichidan),
            VoiceReverseRule(.causative, "saseru", "ru", .ichidan),
            VoiceReverseRule(.passive, "rareru", "ru", .ichidan),
            VoiceReverseRule(.causativePassive, "saserareru", "suru", .suru),
            VoiceReverseRule(.causative, "saseru", "suru", .suru),
            VoiceReverseRule(.passive, "sareru", "suru", .suru),
            VoiceReverseRule(.causativePassive, "jisaserareru", "zuru", .zuru),
            VoiceReverseRule(.causative, "jisaseru", "zuru", .zuru),
            VoiceReverseRule(.passive, "jirareru", "zuru", .zuru),
            VoiceReverseRule(.causativePassive, "kosaserareru", "kuru", .kuru),
            VoiceReverseRule(.causative, "kosaseru", "kuru", .kuru),
            VoiceReverseRule(.passive, "korareru", "kuru", .kuru)
        ])
        return rules
    }()

    private let dictionary: VerbConjugationDictionary

    public init(dictionary: VerbConjugationDictionary) {
        self.dictionary = dictionary
    }

    public func candidates(for input: String) -> [String] {
        let reading = RomajiCanonicalizer.canonicalInput(from: input)
        var costs: [String: (cost: Int, order: Int)] = [:]
        var bareContinuatives: [(surface: String, cost: Int)] = []
        func record(_ candidate: String, cost: Int) {
            let order = costs[candidate]?.order ?? costs.count
            costs[candidate] = (
                min(cost, costs[candidate]?.cost ?? .max),
                order
            )
        }
        for following in Self.followingExpressions
        where !following.derivedOnly
            && reading.hasSuffix(following.readingSuffix) {
            let formReading = String(
                reading.dropLast(following.readingSuffix.count)
            )
            guard !formReading.isEmpty else { continue }
            for baseReading in Self.baseReadings(
                forming: formReading,
                as: following.requiredVerbForm
            ) {
                let kanaReading = RomajiConverter().hiragana(from: baseReading)
                for entry in dictionary.entries(for: baseReading)
                where entry.surface != kanaReading {
                    guard let conjugated = Self.conjugate(
                        entry,
                        to: following.requiredVerbForm
                    ), conjugated.reading == formReading else { continue }
                    record(
                        conjugated.surface + following.surfaceSuffix,
                        cost: entry.cost
                    )
                }
            }
        }
        // A passive or causative verb is an ichidan verb, so it takes the
        // same expressions after the same ichidan forms
        for following in Self.followingExpressions
        where reading.hasSuffix(following.readingSuffix) {
            let formReading = String(
                reading.dropLast(following.readingSuffix.count)
            )
            let formEnding = Self.nonGodanEnding(
                .ichidan,
                following.requiredVerbForm
            ).reading
            guard formReading.hasSuffix(formEnding) else { continue }
            let derivedReading = String(
                formReading.dropLast(formEnding.count)
            ) + "ru"
            for rule in Self.voiceReverseRules
            where derivedReading.hasSuffix(rule.derivedEnding) {
                let baseReading = String(
                    derivedReading.dropLast(rule.derivedEnding.count)
                ) + rule.baseEnding
                for entry in dictionary.entries(for: baseReading)
                where entry.conjugationClass == rule.conjugationClass {
                    guard let derived = Self.derive(entry, as: rule.voice),
                          let conjugated = Self.conjugate(
                            derived,
                            to: following.requiredVerbForm
                          ),
                          conjugated.reading == formReading else { continue }
                    if following.isBareContinuative {
                        bareContinuatives.append(
                            (conjugated.surface, entry.cost)
                        )
                    } else {
                        record(
                            conjugated.surface + following.surfaceSuffix,
                            cost: entry.cost
                        )
                    }
                }
            }
        }
        // A bare stem such as つかれ fits many verbs, so only the most
        // common ones are offered
        for (surface, cost) in bareContinuatives
            .sorted(by: { $0.cost < $1.cost })
            .prefix(Self.maximumBareContinuativeCandidates) {
            record(surface, cost: cost)
        }
        return costs.sorted {
            ($0.value.cost, $0.value.order) < ($1.value.cost, $1.value.order)
        }.map(\.key)
    }

    /// The ichidan verb such as 呼ばれる derived from `entry`
    private static func derive(
        _ entry: VerbConjugationDictionary.Entry,
        as voice: DerivedVoice
    ) -> VerbConjugationDictionary.Entry? {
        let stem: (reading: String, surface: String)
        let suffix: (reading: String, surface: String)?
        switch entry.conjugationClass {
        case .godan, .godanIku:
            guard let value = conjugate(entry, to: .negative) else {
                return nil
            }
            stem = value
            // The reading of 待つ also ends in su, so the kana decides
            suffix = entry.surface.hasSuffix("す")
                ? voice.godanSuffixAfterSu
                : voice.godanSuffix
        case .ichidan, .zuru:
            guard let value = conjugate(entry, to: .continuative) else {
                return nil
            }
            stem = value
            suffix = voice.nonGodanSuffix
        case .suru:
            guard let value = replacingEnding(
                of: entry,
                reading: "suru",
                kana: "する",
                with: ("sa", "さ")
            ) else { return nil }
            stem = value
            suffix = voice.suruSuffix
        case .kuru:
            guard let value = conjugate(entry, to: .negative) else {
                return nil
            }
            stem = value
            suffix = voice.nonGodanSuffix
        }
        guard let suffix else { return nil }
        return VerbConjugationDictionary.Entry(
            reading: stem.reading + suffix.reading,
            surface: stem.surface + suffix.surface,
            conjugationClass: .ichidan,
            cost: entry.cost
        )
    }

    static func conjugate(
        _ entry: VerbConjugationDictionary.Entry,
        to form: VerbConjugationForm
    ) -> (reading: String, surface: String)? {
        switch entry.conjugationClass {
        case .godan, .godanIku:
            guard let row = GodanRow.rows.first(where: {
                entry.reading.hasSuffix($0.reading)
                    && entry.surface.hasSuffix($0.kana)
            }) else { return nil }
            let ending = entry.conjugationClass == .godanIku
                ? GodanRow.iku.ending(for: form)
                : row.ending(for: form)
            return (
                String(entry.reading.dropLast(row.reading.count))
                    + ending.reading,
                String(entry.surface.dropLast(row.kana.count)) + ending.kana
            )
        case .ichidan, .suru, .zuru:
            let baseEnding = nonGodanEnding(entry.conjugationClass, .terminal)
            return replacingEnding(
                of: entry,
                reading: baseEnding.reading,
                kana: baseEnding.kana,
                with: nonGodanEnding(entry.conjugationClass, form)
            )
        case .kuru:
            let kana = entry.surface.hasSuffix("来る") ? "来る" : "くる"
            let ending = nonGodanEnding(.kuru, form)
            return replacingEnding(
                of: entry,
                reading: "kuru",
                kana: kana,
                with: (
                    ending.reading,
                    kana == "来る"
                        ? "来" + ending.kana.dropFirst()
                        : ending.kana
                )
            )
        }
    }

    /// Forms of the verb classes other than 五段, written in kana
    private static func nonGodanEnding(
        _ conjugationClass: VerbConjugationClass,
        _ form: VerbConjugationForm
    ) -> (reading: String, kana: String) {
        let endings: [VerbConjugationForm: (String, String)]
        switch conjugationClass {
        case .godan, .godanIku, .ichidan:
            endings = [
                .continuative: ("", ""), .negative: ("", ""),
                .te: ("te", "て"), .past: ("ta", "た"),
                .conditional: ("re", "れ"), .terminal: ("ru", "る")
            ]
        case .suru:
            endings = [
                .continuative: ("shi", "し"), .negative: ("shi", "し"),
                .te: ("shite", "して"), .past: ("shita", "した"),
                .conditional: ("sure", "すれ"), .terminal: ("suru", "する")
            ]
        case .zuru:
            endings = [
                .continuative: ("ji", "じ"), .negative: ("ji", "じ"),
                .te: ("jite", "じて"), .past: ("jita", "じた"),
                .conditional: ("zure", "ずれ"), .terminal: ("zuru", "ずる")
            ]
        case .kuru:
            endings = [
                .continuative: ("ki", "き"), .negative: ("ko", "こ"),
                .te: ("kite", "きて"), .past: ("kita", "きた"),
                .conditional: ("kure", "くれ"), .terminal: ("kuru", "くる")
            ]
        }
        return endings[form]!
    }

    private static func replacingEnding(
        of entry: VerbConjugationDictionary.Entry,
        reading: String,
        kana: String,
        with ending: (reading: String, kana: String)
    ) -> (reading: String, surface: String)? {
        guard entry.reading.hasSuffix(reading),
              entry.surface.hasSuffix(kana) else { return nil }
        return (
            String(entry.reading.dropLast(reading.count)) + ending.reading,
            String(entry.surface.dropLast(kana.count)) + ending.kana
        )
    }

    private enum DerivedVoice: Sendable {
        case passive
        case causative
        case causativePassive
        /// 呼ばされる, the short 使役受身 of 五段 verbs
        case shortCausativePassive

        var godanSuffix: (reading: String, surface: String)? {
            switch self {
            case .passive: ("reru", "れる")
            case .causative: ("seru", "せる")
            case .causativePassive: ("serareru", "せられる")
            case .shortCausativePassive: ("sareru", "される")
            }
        }

        /// 話さされる is not used; 話させられる is the only form
        var godanSuffixAfterSu: (reading: String, surface: String)? {
            self == .shortCausativePassive ? nil : godanSuffix
        }

        var nonGodanSuffix: (reading: String, surface: String)? {
            switch self {
            case .passive: ("rareru", "られる")
            case .causative: ("saseru", "させる")
            case .causativePassive: ("saserareru", "させられる")
            case .shortCausativePassive: nil
            }
        }

        var suruSuffix: (reading: String, surface: String)? {
            switch self {
            case .passive: ("reru", "れる")
            case .causative: ("seru", "せる")
            case .causativePassive: ("serareru", "せられる")
            case .shortCausativePassive: nil
            }
        }
    }

    private struct VoiceReverseRule: Sendable {
        let voice: DerivedVoice
        let derivedEnding: String
        let baseEnding: String
        let conjugationClass: VerbConjugationClass

        init(
            _ voice: DerivedVoice,
            _ derivedEnding: String,
            _ baseEnding: String,
            _ conjugationClass: VerbConjugationClass
        ) {
            self.voice = voice
            self.derivedEnding = derivedEnding
            self.baseEnding = baseEnding
            self.conjugationClass = conjugationClass
        }
    }

    /// Base readings that may produce `formReading`; the dictionary lookup
    /// and forward conjugation decide which of them are real verbs
    private static func baseReadings(
        forming formReading: String,
        as form: VerbConjugationForm
    ) -> [String] {
        var result: [String] = []
        func append(_ stem: Substring, _ ending: String) {
            let base = String(stem) + ending
            if !result.contains(base) { result.append(base) }
        }
        for row in GodanRow.rows + [GodanRow.iku] {
            let ending = row.ending(for: form).reading
            if formReading.hasSuffix(ending) {
                append(formReading.dropLast(ending.count), row.reading)
            }
        }
        for conjugationClass in [
            VerbConjugationClass.ichidan, .suru, .zuru, .kuru
        ] {
            let ending = nonGodanEnding(conjugationClass, form).reading
            let base = nonGodanEnding(conjugationClass, .terminal).reading
            if formReading.hasSuffix(ending) {
                append(formReading.dropLast(ending.count), base)
            }
        }
        return result
    }
}

private struct GodanRow: Sendable {
    let reading: String
    let kana: String
    let continuative: (String, String)
    let negative: (String, String)
    let te: (String, String)
    let past: (String, String)
    let conditional: (String, String)

    func ending(
        for form: VerbConjugationForm
    ) -> (reading: String, kana: String) {
        switch form {
        case .continuative: continuative
        case .negative: negative
        case .te: te
        case .past: past
        case .conditional: conditional
        case .terminal: (reading, kana)
        }
    }

    static let rows: [GodanRow] = [
        GodanRow(reading: "tsu", kana: "つ", continuative: ("chi", "ち"),
                 negative: ("ta", "た"), te: ("tte", "って"), past: ("tta", "った"),
                 conditional: ("te", "て")),
        GodanRow(reading: "su", kana: "す", continuative: ("shi", "し"),
                 negative: ("sa", "さ"), te: ("shite", "して"), past: ("shita", "した"),
                 conditional: ("se", "せ")),
        GodanRow(reading: "ku", kana: "く", continuative: ("ki", "き"),
                 negative: ("ka", "か"), te: ("ite", "いて"), past: ("ita", "いた"),
                 conditional: ("ke", "け")),
        GodanRow(reading: "gu", kana: "ぐ", continuative: ("gi", "ぎ"),
                 negative: ("ga", "が"), te: ("ide", "いで"), past: ("ida", "いだ"),
                 conditional: ("ge", "げ")),
        GodanRow(reading: "nu", kana: "ぬ", continuative: ("ni", "に"),
                 negative: ("na", "な"), te: ("nde", "んで"), past: ("nda", "んだ"),
                 conditional: ("ne", "ね")),
        GodanRow(reading: "bu", kana: "ぶ", continuative: ("bi", "び"),
                 negative: ("ba", "ば"), te: ("nde", "んで"), past: ("nda", "んだ"),
                 conditional: ("be", "べ")),
        GodanRow(reading: "mu", kana: "む", continuative: ("mi", "み"),
                 negative: ("ma", "ま"), te: ("nde", "んで"), past: ("nda", "んだ"),
                 conditional: ("me", "め")),
        GodanRow(reading: "ru", kana: "る", continuative: ("ri", "り"),
                 negative: ("ra", "ら"), te: ("tte", "って"), past: ("tta", "った"),
                 conditional: ("re", "れ")),
        GodanRow(reading: "u", kana: "う", continuative: ("i", "い"),
                 negative: ("wa", "わ"), te: ("tte", "って"), past: ("tta", "った"),
                 conditional: ("e", "え"))
    ]

    static let iku = GodanRow(
        reading: "ku", kana: "く", continuative: ("ki", "き"),
        negative: ("ka", "か"), te: ("tte", "って"), past: ("tta", "った"),
        conditional: ("ke", "け")
    )
}
