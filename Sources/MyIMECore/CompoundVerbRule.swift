/// A verb joined after the 連用形 of another, as 終わる in し終わる; the
/// compound conjugates as the joined verb does, so し終わった follows the
/// godan 終わる and し始めた the ichidan 始める
struct CompoundVerbRule: Sendable {
    let reading: String
    let surface: String
    let conjugationClass: VerbConjugationClass
    /// Joined only after common verbs, for verbs such as 込む and 合う whose
    /// meaning limits what they follow
    let commonHeadsOnly: Bool
    /// Added to the cost of the verb before it, so these combinations come
    /// after the more usual ones
    let costPenalty: Int
    /// Follows the bare する, as in し過ぎる; し上げる and し込む read like
    /// 仕上げる and 仕込む and are not offered
    let followsSuru: Bool

    init(
        _ reading: String,
        _ surface: String,
        _ conjugationClass: VerbConjugationClass,
        commonHeadsOnly: Bool = false,
        costPenalty: Int = 0,
        followsSuru: Bool = true
    ) {
        self.reading = reading
        self.surface = surface
        self.conjugationClass = conjugationClass
        self.commonHeadsOnly = commonHeadsOnly
        self.costPenalty = costPenalty
        self.followsSuru = followsSuru
    }

    /// Cost added to the combinations that follow fewer verbs naturally
    static let narrowPenalty = 4500

    static let all: [CompoundVerbRule] = [
        CompoundVerbRule("tsuzukeru", "続ける", .ichidan),
        CompoundVerbRule("owaru", "終わる", .godan),
        CompoundVerbRule("oeru", "終える", .ichidan),
        CompoundVerbRule("hajimeru", "始める", .ichidan),
        CompoundVerbRule("naosu", "直す", .godan),
        CompoundVerbRule("kiru", "切る", .godan),
        CompoundVerbRule("wasureru", "忘れる", .ichidan),
        CompoundVerbRule(
            "kakeru", "かける", .ichidan,
            commonHeadsOnly: true, costPenalty: narrowPenalty,
            followsSuru: false
        ),
        CompoundVerbRule(
            "sugiru", "過ぎる", .ichidan,
            commonHeadsOnly: true, costPenalty: narrowPenalty
        ),
        CompoundVerbRule(
            "dasu", "出す", .godan,
            commonHeadsOnly: true, costPenalty: narrowPenalty,
            followsSuru: false
        ),
        CompoundVerbRule(
            "komu", "込む", .godan,
            commonHeadsOnly: true, costPenalty: narrowPenalty,
            followsSuru: false
        ),
        CompoundVerbRule(
            "au", "合う", .godan,
            commonHeadsOnly: true, costPenalty: narrowPenalty,
            followsSuru: false
        ),
        CompoundVerbRule(
            "nuku", "抜く", .godan,
            commonHeadsOnly: true, costPenalty: narrowPenalty,
            followsSuru: false
        ),
        CompoundVerbRule(
            "ageru", "上げる", .ichidan,
            commonHeadsOnly: true, costPenalty: narrowPenalty,
            followsSuru: false
        )
    ]
}
