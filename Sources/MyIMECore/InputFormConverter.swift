import Foundation

public enum InputForm: Sendable {
    case hiragana
    case fullWidthKatakana
    case halfWidthKatakana
    case fullWidthAlphanumeric
    case halfWidthAlphanumeric
}

public enum InputFormConverter {
    public static func convert(_ input: String, to form: InputForm) -> String? {
        guard !input.isEmpty else { return nil }
        switch form {
        case .hiragana:
            return RomajiConverter().hiragana(from: input)
        case .fullWidthKatakana:
            return RomajiConverter().katakana(from: input)
        case .halfWidthKatakana:
            return RomajiConverter().katakana(from: input)?.applyingTransform(
                .fullwidthToHalfwidth,
                reverse: false
            )
        case .fullWidthAlphanumeric:
            return input.applyingTransform(
                .fullwidthToHalfwidth,
                reverse: true
            )
        case .halfWidthAlphanumeric:
            return input
        }
    }
}
