import Foundation

public enum EmojiSearchActivationPolicy {
    public static func startsInSelectionMode(searchText: String) -> Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
