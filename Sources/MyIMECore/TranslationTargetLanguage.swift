public struct TranslationTargetLanguage: Equatable, Sendable {
    public let identifier: String
    public let name: String

    public init(identifier: String, name: String) {
        self.identifier = identifier
        self.name = name
    }

    public static let available: [TranslationTargetLanguage] = [
        .init(identifier: "en", name: "英語"),
        .init(identifier: "zh-Hans", name: "中国語（簡体字）"),
        .init(identifier: "zh-Hant", name: "中国語（繁体字）"),
        .init(identifier: "ko", name: "韓国語"),
        .init(identifier: "fr", name: "フランス語"),
        .init(identifier: "de", name: "ドイツ語"),
        .init(identifier: "es", name: "スペイン語"),
        .init(identifier: "it", name: "イタリア語"),
        .init(identifier: "pt-BR", name: "ポルトガル語"),
        .init(identifier: "nl", name: "オランダ語"),
        .init(identifier: "pl", name: "ポーランド語"),
        .init(identifier: "ru", name: "ロシア語"),
        .init(identifier: "uk", name: "ウクライナ語"),
        .init(identifier: "tr", name: "トルコ語"),
        .init(identifier: "ar", name: "アラビア語"),
        .init(identifier: "th", name: "タイ語"),
        .init(identifier: "vi", name: "ベトナム語"),
        .init(identifier: "id", name: "インドネシア語")
    ]

    public static func language(forIdentifier identifier: String) -> Self? {
        available.first { $0.identifier == identifier }
    }

    public static func languages<S: Sequence>(
        forIdentifiers identifiers: S
    ) -> [Self] where S.Element == String {
        let selected = Set(identifiers)
        return available.filter { selected.contains($0.identifier) }
    }
}
