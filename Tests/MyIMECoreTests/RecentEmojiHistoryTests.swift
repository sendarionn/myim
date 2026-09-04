import Testing
@testable import MyIMECore

struct RecentEmojiHistoryTests {
    @Test func keepsTheLatestTenEmojis() {
        var history = RecentEmojiHistory()
        for index in 0..<12 {
            history.record("emoji-\(index)")
        }

        #expect(history.emojis.count == 10)
        #expect(history.emojis.first == "emoji-11")
        #expect(history.emojis.last == "emoji-2")
    }

    @Test func movesAReusedEmojiToTheFront() {
        var history = RecentEmojiHistory(emojis: ["😀", "😃", "😄"])
        history.record("😃")

        #expect(history.emojis == ["😃", "😀", "😄"])
    }

    @Test func removesDuplicatesAndEmptyValuesWhenLoading() {
        let history = RecentEmojiHistory(
            emojis: ["😀", "", "😀", "😃"]
        )

        #expect(history.emojis == ["😀", "😃"])
    }
}
