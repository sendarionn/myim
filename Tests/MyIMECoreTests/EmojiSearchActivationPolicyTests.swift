import Testing
@testable import MyIMECore

@Suite
struct EmojiSearchActivationPolicyTests {
    @Test
    func startsInSelectionModeWhenOpenedWithComposition() {
        #expect(EmojiSearchActivationPolicy.startsInSelectionMode(
            searchText: "えがお"
        ))
        #expect(EmojiSearchActivationPolicy.startsInSelectionMode(
            searchText: "笑顔"
        ))
    }

    @Test
    func keepsEmptyOpeningReadyForSearchInput() {
        #expect(!EmojiSearchActivationPolicy.startsInSelectionMode(
            searchText: ""
        ))
        #expect(!EmojiSearchActivationPolicy.startsInSelectionMode(
            searchText: "　"
        ))
    }

    @Test
    func hidesRecentEmojisWhileSearchingAndShowingResults() {
        #expect(EmojiSearchActivationPolicy.showsRecentEmojis(
            searchText: ""
        ))
        #expect(EmojiSearchActivationPolicy.showsRecentEmojis(
            searchText: "　"
        ))
        #expect(!EmojiSearchActivationPolicy.showsRecentEmojis(
            searchText: "えがお"
        ))
        #expect(!EmojiSearchActivationPolicy.showsRecentEmojis(
            searchText: "smile"
        ))
    }

    @Test
    func usesTabForEmojiNavigationOutsideSearchConversion() {
        #expect(EmojiSearchActivationPolicy.tabNavigatesEmoji(
            searchText: "",
            isSearchConfirmed: false
        ))
        #expect(!EmojiSearchActivationPolicy.tabNavigatesEmoji(
            searchText: "えがお",
            isSearchConfirmed: false
        ))
        #expect(EmojiSearchActivationPolicy.tabNavigatesEmoji(
            searchText: "えがお",
            isSearchConfirmed: true
        ))
    }

    @Test
    func routesArrowsBetweenSearchCandidatesAndEmojiGrid() {
        #expect(EmojiSearchActivationPolicy.arrowAction(
            direction: .up,
            searchText: "えがお",
            isSearchConfirmed: false
        ) == .moveSearchCandidate)
        #expect(EmojiSearchActivationPolicy.arrowAction(
            direction: .down,
            searchText: "えがお",
            isSearchConfirmed: false
        ) == .moveSearchCandidate)
        #expect(EmojiSearchActivationPolicy.arrowAction(
            direction: .left,
            searchText: "えがお",
            isSearchConfirmed: false
        ) == .enterEmojiSelection)
        #expect(EmojiSearchActivationPolicy.arrowAction(
            direction: .right,
            searchText: "えがお",
            isSearchConfirmed: false
        ) == .enterEmojiSelection)
        #expect(EmojiSearchActivationPolicy.arrowAction(
            direction: .up,
            searchText: "えがお",
            isSearchConfirmed: true
        ) == .moveEmojiSelection)
        #expect(EmojiSearchActivationPolicy.arrowAction(
            direction: .right,
            searchText: "",
            isSearchConfirmed: false
        ) == .moveEmojiSelection)
    }

    @Test
    func returnsFromEmojiSelectionBeforeClosingThePanel() {
        #expect(EmojiSearchActivationPolicy.escapeAction(
            isSearchConfirmed: true
        ) == .resumeSearchEditing)
        #expect(EmojiSearchActivationPolicy.escapeAction(
            isSearchConfirmed: false
        ) == .closePanel)
    }

    @Test
    func clickingAVisibleEmojiCommitsItsExactIndex() {
        #expect(EmojiSearchActivationPolicy.clickAction(
            index: 128,
            itemCount: 256,
            isPanelVisible: true,
            isCommitInProgress: false
        ) == .commit(index: 128))
    }

    @Test
    func ignoresInvalidOrRepeatedEmojiClicks() {
        #expect(EmojiSearchActivationPolicy.clickAction(
            index: 0,
            itemCount: 1,
            isPanelVisible: false,
            isCommitInProgress: false
        ) == .ignore)
        #expect(EmojiSearchActivationPolicy.clickAction(
            index: 0,
            itemCount: 1,
            isPanelVisible: true,
            isCommitInProgress: true
        ) == .ignore)
        #expect(EmojiSearchActivationPolicy.clickAction(
            index: 1,
            itemCount: 1,
            isPanelVisible: true,
            isCommitInProgress: false
        ) == .ignore)
    }
}
