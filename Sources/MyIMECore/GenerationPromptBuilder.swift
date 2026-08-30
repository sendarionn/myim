public enum GenerationPromptBuilder {
    public static func prompt(requirements: String, purpose: String) -> String? {
        let trimmedRequirements = requirements.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPurpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRequirements.isEmpty || !trimmedPurpose.isEmpty else {
            return nil
        }

        return """
        次の断片的な情報から、そのまま相手へ送信または文書へ記載できる自然な日本語の文章を作成してください
        用途、相手との関係、丁寧さ、文体は入力内容から推定してください
        入力にない固有名詞、日付、金額、事実は創作しないでください
        説明、見出し、引用符、注釈、候補は付けず、完成した本文だけを出力してください

        要件:
        \(trimmedRequirements.isEmpty ? "未指定" : trimmedRequirements)

        目的:
        \(trimmedPurpose.isEmpty ? "未指定" : trimmedPurpose)
        """
    }

    public static func normalizeGeneratedText(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let wrappers: [(Character, Character)] = [
            ("「", "」"), ("『", "』"), ("（", "）"), ("(", ")"),
            ("\"", "\""), ("“", "”")
        ]
        while let pair = wrappers.first(where: {
            result.first == $0.0 && result.last == $0.1
        }), result.count >= 2 {
            result.removeFirst()
            result.removeLast()
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = pair
        }
        return result
    }
}
