import Foundation

public enum MeaningInputReturnAction: Equatable, Sendable {
    case confirmCurrentInput
    case search
    case none
}

public enum MeaningInputReturnPolicy {
    public static func action(
        hasCurrentInput: Bool,
        hasConfirmedDraft: Bool
    ) -> MeaningInputReturnAction {
        if hasCurrentInput { return .confirmCurrentInput }
        if hasConfirmedDraft { return .search }
        return .none
    }
}

public enum MeaningSearchPromptBuilder {
    public static func prompt(
        for description: String,
        excluding excludedCandidates: [String] = []
    ) -> String? {
        let input = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }
        let exclusions = excludedCandidates.isEmpty
            ? ""
            : """

            次の候補は使わず、別の見出し語を挙げてください
            \(excludedCandidates.prefix(32).joined(separator: "、"))
            """
        return """
        次の説明が表す日本語の語句を最大32個挙げてください
        国語辞典の見出し語として載る単語、熟語、四字熟語、慣用語、文語を幅広く検討してください
        入力の言い換えではなく、説明に対応する語句を検索するように答えてください
        文章、説明文、活用を伴う表現ではなく、単独で辞書を引ける見出し語だけを答えてください
        各候補を1行に1つだけ書き、番号、箇条書き、説明、引用符は付けないでください

        説明: \(input)\(exclusions)
        """
    }

    public static func candidates(from response: String, limit: Int = 32) -> [String] {
        guard limit > 0 else { return [] }
        var seen = Set<String>()
        return response.split(whereSeparator: \Character.isNewline)
            .compactMap { line -> String? in
                var value = line.trimmingCharacters(in: .whitespacesAndNewlines)
                value = value.replacingOccurrences(
                    of: #"^\s*(?:[-*•・]|\d+[.、)])\s*"#,
                    with: "",
                    options: .regularExpression
                )
                value = value.trimmingCharacters(
                    in: CharacterSet(charactersIn: " \t「」『』\"“”")
                )
                guard !value.isEmpty, value.count <= 40,
                      seen.insert(value).inserted else { return nil }
                return value
            }
            .prefix(limit)
            .map { $0 }
    }
}
