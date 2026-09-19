public struct TranslationTargetLanguage: Equatable, Sendable {
    public let prefix: String
    public let identifier: String
    public let name: String

    public init(prefix: String, identifier: String, name: String) {
        self.prefix = prefix
        self.identifier = identifier
        self.name = name
    }

    public static let available: [TranslationTargetLanguage] = [
        .init(prefix: "en", identifier: "en", name: "英語"),
        .init(prefix: "zh", identifier: "zh-Hans", name: "中国語（簡体字）"),
        .init(prefix: "zht", identifier: "zh-Hant", name: "中国語（繁体字）"),
        .init(prefix: "ko", identifier: "ko", name: "韓国語"),
        .init(prefix: "fr", identifier: "fr", name: "フランス語"),
        .init(prefix: "de", identifier: "de", name: "ドイツ語"),
        .init(prefix: "es", identifier: "es", name: "スペイン語"),
        .init(prefix: "it", identifier: "it", name: "イタリア語"),
        .init(prefix: "pt", identifier: "pt-BR", name: "ポルトガル語"),
        .init(prefix: "nl", identifier: "nl", name: "オランダ語"),
        .init(prefix: "pl", identifier: "pl", name: "ポーランド語"),
        .init(prefix: "ru", identifier: "ru", name: "ロシア語"),
        .init(prefix: "uk", identifier: "uk", name: "ウクライナ語"),
        .init(prefix: "tr", identifier: "tr", name: "トルコ語"),
        .init(prefix: "ar", identifier: "ar", name: "アラビア語"),
        .init(prefix: "th", identifier: "th", name: "タイ語"),
        .init(prefix: "vi", identifier: "vi", name: "ベトナム語"),
        .init(prefix: "id", identifier: "id", name: "インドネシア語")
    ]

    public static func language(forPrefix prefix: String) -> Self? {
        let normalized = prefix.lowercased()
        return available.first { $0.prefix == normalized }
    }
}
