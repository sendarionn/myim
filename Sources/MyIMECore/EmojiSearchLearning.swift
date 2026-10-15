import Foundation

/// Decides when confirming an emoji search teaches the conversion history
///
/// A search built from a chosen conversion candidate is learned as if the
/// candidate were committed, once until the search text changes
public struct EmojiSearchLearning: Equatable, Sendable {
    private var learnedSearchText: String?

    public init() {}

    /// Whether confirming `searchText` should record its candidate
    public mutating func learns(
        confirming searchText: String,
        choseCandidate: Bool
    ) -> Bool {
        guard choseCandidate,
              !searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty,
              searchText != learnedSearchText else {
            return false
        }
        learnedSearchText = searchText
        return true
    }

    /// Editing the search to other text allows learning it again
    public mutating func searchChanged(to searchText: String) {
        if searchText != learnedSearchText {
            learnedSearchText = nil
        }
    }

    public mutating func reset() {
        learnedSearchText = nil
    }
}
