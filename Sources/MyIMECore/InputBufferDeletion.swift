import Foundation

public enum InputBufferDeletionUnit: Sendable {
    case character
    case word
    case all
}

public enum InputBufferDeletion {
    public static func deletingBackward(
        from value: String,
        unit: InputBufferDeletionUnit
    ) -> String {
        guard !value.isEmpty else { return value }
        switch unit {
        case .character:
            return String(value.dropLast())
        case .all:
            return ""
        case .word:
            var result = value
            while let last = result.last, !isWordCharacter(last) {
                result.removeLast()
            }
            while let last = result.last, isWordCharacter(last) {
                result.removeLast()
            }
            return result
        }
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0)
                || $0 == "-"
                || $0 == "'"
        }
    }
}
