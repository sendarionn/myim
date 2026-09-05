import Foundation

public struct SymbolTips: Equatable, Sendable {
    public let character: String
    public let codePoint: String
    public let unicodeName: String

    public static func make(for text: String) -> SymbolTips? {
        let scalars = text.unicodeScalars.filter {
            $0.value != 0xFE0E && $0.value != 0xFE0F
        }
        guard text.count == 1, scalars.count == 1, let scalar = scalars.first else {
            return nil
        }
        let categoryName = String(describing: scalar.properties.generalCategory)
        let isSymbol = categoryName.contains("Symbol")
            || categoryName.contains("Punctuation")
        guard isSymbol || text == "ー" else { return nil }

        return SymbolTips(
            character: text,
            codePoint: String(format: "U+%04X", scalar.value),
            unicodeName: scalar.properties.name ?? "名称情報なし"
        )
    }
}
