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

    /// Whether a dictionary verb with this reading and surface allows the
    /// class; unknown verbs are not rejected
    public func allows(
        reading: String,
        surface: String,
        classes: Set<VerbConjugationClass>
    ) -> Bool {
        let known = entries(for: reading).filter { $0.surface == surface }
        return known.isEmpty
            || known.contains { classes.contains($0.conjugationClass) }
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

        init(
            _ readingSuffix: String,
            _ surfaceSuffix: String,
            requiring requiredVerbForm: VerbConjugationForm
        ) {
            self.requiredVerbForm = requiredVerbForm
            self.readingSuffix = readingSuffix
            self.surfaceSuffix = surfaceSuffix
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
        FollowingExpression("", "", requiring: .te),
        FollowingExpression("", "", requiring: .past),
        FollowingExpression("masu", "ます", requiring: .continuative),
        FollowingExpression("mashita", "ました", requiring: .continuative),
        FollowingExpression("masen", "ません", requiring: .continuative),
        FollowingExpression("iru", "いる", requiring: .te),
        FollowingExpression("ita", "いた", requiring: .te),
        FollowingExpression("inai", "いない", requiring: .te),
        FollowingExpression("imasu", "います", requiring: .te),
        FollowingExpression("nai", "ない", requiring: .negative),
        FollowingExpression("nakatta", "なかった", requiring: .negative)
    ]

    private static let followingExpressions =
        desireChanges + desireInflections + otherFollowings

    private let dictionary: VerbConjugationDictionary

    public init(dictionary: VerbConjugationDictionary) {
        self.dictionary = dictionary
    }

    public func candidates(for input: String) -> [String] {
        let reading = RomajiCanonicalizer.canonicalInput(from: input)
        var costs: [String: (cost: Int, order: Int)] = [:]
        for following in Self.followingExpressions
        where reading.hasSuffix(following.readingSuffix) {
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
                    let candidate = conjugated.surface
                        + following.surfaceSuffix
                    let order = costs[candidate]?.order ?? costs.count
                    costs[candidate] = (
                        min(entry.cost, costs[candidate]?.cost ?? .max),
                        order
                    )
                }
            }
        }
        return costs.sorted {
            ($0.value.cost, $0.value.order) < ($1.value.cost, $1.value.order)
        }.map(\.key)
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
        case .ichidan:
            return replacingEnding(
                of: entry,
                reading: "ru",
                kana: "る",
                with: [
                    .continuative: ("", ""),
                    .negative: ("", ""),
                    .te: ("te", "て"),
                    .past: ("ta", "た")
                ][form]!
            )
        case .suru:
            return replacingEnding(
                of: entry,
                reading: "suru",
                kana: "する",
                with: [
                    .continuative: ("shi", "し"),
                    .negative: ("shi", "し"),
                    .te: ("shite", "して"),
                    .past: ("shita", "した")
                ][form]!
            )
        case .zuru:
            return replacingEnding(
                of: entry,
                reading: "zuru",
                kana: "ずる",
                with: [
                    .continuative: ("ji", "じ"),
                    .negative: ("ji", "じ"),
                    .te: ("jite", "じて"),
                    .past: ("jita", "じた")
                ][form]!
            )
        case .kuru:
            let kana = entry.surface.hasSuffix("来る") ? "来る" : "くる"
            let ending: (reading: String, kana: String) = [
                .continuative: ("ki", "き"),
                .negative: ("ko", "こ"),
                .te: ("kite", "きて"),
                .past: ("kita", "きた")
            ][form]!
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
        let irregular: [(ending: String, base: String)] = [
            ("", "ru"),
            ("shi", "suru"), ("ji", "zuru"), ("ki", "kuru"), ("ko", "kuru")
        ]
        let formEnding = [
            .continuative: "", .negative: "", .te: "te", .past: "ta"
        ][form]!
        guard formReading.hasSuffix(formEnding) else { return result }
        let stem = formReading.dropLast(formEnding.count)
        for rule in irregular where stem.hasSuffix(rule.ending) {
            append(stem.dropLast(rule.ending.count), rule.base)
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

    func ending(
        for form: VerbConjugationForm
    ) -> (reading: String, kana: String) {
        switch form {
        case .continuative: continuative
        case .negative: negative
        case .te: te
        case .past: past
        }
    }

    static let rows: [GodanRow] = [
        GodanRow(reading: "tsu", kana: "つ", continuative: ("chi", "ち"),
                 negative: ("ta", "た"), te: ("tte", "って"), past: ("tta", "った")),
        GodanRow(reading: "su", kana: "す", continuative: ("shi", "し"),
                 negative: ("sa", "さ"), te: ("shite", "して"), past: ("shita", "した")),
        GodanRow(reading: "ku", kana: "く", continuative: ("ki", "き"),
                 negative: ("ka", "か"), te: ("ite", "いて"), past: ("ita", "いた")),
        GodanRow(reading: "gu", kana: "ぐ", continuative: ("gi", "ぎ"),
                 negative: ("ga", "が"), te: ("ide", "いで"), past: ("ida", "いだ")),
        GodanRow(reading: "nu", kana: "ぬ", continuative: ("ni", "に"),
                 negative: ("na", "な"), te: ("nde", "んで"), past: ("nda", "んだ")),
        GodanRow(reading: "bu", kana: "ぶ", continuative: ("bi", "び"),
                 negative: ("ba", "ば"), te: ("nde", "んで"), past: ("nda", "んだ")),
        GodanRow(reading: "mu", kana: "む", continuative: ("mi", "み"),
                 negative: ("ma", "ま"), te: ("nde", "んで"), past: ("nda", "んだ")),
        GodanRow(reading: "ru", kana: "る", continuative: ("ri", "り"),
                 negative: ("ra", "ら"), te: ("tte", "って"), past: ("tta", "った")),
        GodanRow(reading: "u", kana: "う", continuative: ("i", "い"),
                 negative: ("wa", "わ"), te: ("tte", "って"), past: ("tta", "った"))
    ]

    static let iku = GodanRow(
        reading: "ku", kana: "く", continuative: ("ki", "き"),
        negative: ("ka", "か"), te: ("tte", "って"), past: ("tta", "った")
    )
}
