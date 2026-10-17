import Foundation

public enum EmojiSearchArrowAction: Equatable {
    case moveSearchCandidate
    case enterEmojiSelection
    case moveEmojiSelection
}

public enum EmojiSearchEscapeAction: Equatable {
    case resumeSearchEditing
    case closePanel
}

public enum EmojiClickAction: Equatable {
    case commit(index: Int)
    case ignore
}

public enum EmojiSearchActivationPolicy {
    public static func startsInSelectionMode(searchText: String) -> Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func showsRecentEmojis(searchText: String) -> Bool {
        !startsInSelectionMode(searchText: searchText)
    }

    public static func tabNavigatesEmoji(
        searchText: String,
        isSearchConfirmed: Bool
    ) -> Bool {
        isSearchConfirmed || searchText.isEmpty
    }

    public static func arrowAction(
        direction: EmojiGridDirection,
        searchText: String,
        isSearchConfirmed: Bool
    ) -> EmojiSearchArrowAction {
        if tabNavigatesEmoji(
            searchText: searchText,
            isSearchConfirmed: isSearchConfirmed
        ) {
            return .moveEmojiSelection
        }
        switch direction {
        case .up, .down:
            return .moveSearchCandidate
        case .left, .right:
            return .enterEmojiSelection
        }
    }

    public static func escapeAction(
        isSearchConfirmed: Bool
    ) -> EmojiSearchEscapeAction {
        isSearchConfirmed ? .resumeSearchEditing : .closePanel
    }

    public static func clickAction(
        index: Int,
        itemCount: Int,
        isPanelVisible: Bool,
        isCommitInProgress: Bool
    ) -> EmojiClickAction {
        guard isPanelVisible,
              !isCommitInProgress,
              (0..<itemCount).contains(index) else {
            return .ignore
        }
        return .commit(index: index)
    }
}
