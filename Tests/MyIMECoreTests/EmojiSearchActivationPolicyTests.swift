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
}
