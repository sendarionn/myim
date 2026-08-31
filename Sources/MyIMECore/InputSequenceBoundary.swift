import Foundation

public enum InputSequenceBoundary {
    public static func endsWithLineBreak(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.last else { return false }
        return CharacterSet.newlines.contains(scalar)
    }
}
