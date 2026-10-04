import Testing
@testable import MyIMECore

@Suite
struct SelectionServiceTextTests {
    @Test
    func rejectsMissingAndEmptyText() {
        #expect(SelectionServiceText.received(nil) == nil)
        #expect(SelectionServiceText.received("") == nil)
    }

    @Test(arguments: [
        "https://github.com/sendarionn/myim",
        "日本語とemoji🙂",
        "1行目\n2行目",
        "列1\t列2",
        "  前後と  途中の空白  "
    ])
    func preservesSelectedTextExactly(_ text: String) {
        #expect(SelectionServiceText.received(text) == text)
    }

    @Test
    func acceptsWhitespaceOnlyTextWithoutNormalizingIt() {
        #expect(SelectionServiceText.received(" \n\t") == " \n\t")
    }
}
