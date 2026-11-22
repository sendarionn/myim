import Testing
@testable import MyIMECore

@Suite
struct BookmarkSearchSessionTests {
    @Test
    func retainsLoadFailureUntilTheSearchIsClosed() {
        var session = BookmarkSearchSession()
        session.begin()

        session.failLoading("Chromeのブックマークを読み取れません")

        #expect(session.stage == .searching)
        #expect(session.loadError == "Chromeのブックマークを読み取れません")
        #expect(session.filteredBookmarks.isEmpty)
        session.reset()
        #expect(session.loadError == nil)
    }

    private let swift = BrowserBookmark(
        title: "Swift Language",
        url: "https://swift.org",
        folderPath: "Development",
        profile: "Personal"
    )
    private let issue = BrowserBookmark(
        title: "Issue Tracker",
        url: "https://example.com/issues",
        folderPath: "Project Alpha",
        profile: "Work"
    )

    @Test
    func filtersByTitleURLFolderAndProfileWithoutCaseSensitivity() {
        var session = BookmarkSearchSession()
        session.begin()
        session.replaceBookmarks([swift, issue])

        for query in ["swift", "EXAMPLE.COM", "alpha", "work"] {
            session.updateQuery(query)
            #expect(session.filteredBookmarks == [query == "swift" ? swift : issue])
        }
    }

    @Test
    func selectsBookmarkThenReturnsFromFormatsWithoutLosingSearch() {
        var session = BookmarkSearchSession()
        session.begin()
        session.updateQuery("issue")
        session.replaceBookmarks([swift, issue])
        #expect(session.selectedBookmark == issue)

        #expect(session.beginFormatLoading() == issue)
        session.replaceFormats([
            .init(id: "url", label: "URL", text: issue.url),
            .init(
                id: "markdown",
                label: "Markdownリンク",
                text: "[Issue Tracker](https://example.com/issues)"
            )
        ])
        session.moveFormatSelection(by: 1)
        #expect(session.selectedFormat?.id == "markdown")

        session.returnToSearch()
        #expect(session.stage == .searching)
        #expect(session.query == "issue")
        #expect(session.selectedBookmark == issue)
    }

    @Test
    func staleFormatsAreRejectedAfterReturningToSearch() {
        var session = BookmarkSearchSession()
        session.begin()
        session.replaceBookmarks([swift])
        let requested = session.beginFormatLoading()
        session.returnToSearch()

        #expect(requested == swift)
        #expect(!session.acceptsFormats(for: swift))
        session.replaceFormats([.init(id: "url", label: "URL", text: swift.url)])
        #expect(session.formats.isEmpty)
    }

    // MARK: Composing and converting the search text

    private let plan = BrowserBookmark(
        title: "構造計画 - 社内Wiki",
        url: "https://wiki.example.com/plan",
        folderPath: "仕事",
        profile: "Work"
    )

    private func searchingSession() -> BookmarkSearchSession {
        var session = BookmarkSearchSession()
        session.begin()
        session.replaceBookmarks([swift, issue, plan])
        return session
    }

    /// ASCII narrows the list as typed and is kept as typed, as before
    @Test
    func typedRomajiNarrowsTheListBeforeItIsConverted() {
        var session = searchingSession()

        session.appendComposition("swi")
        let narrowed = session.filteredBookmarks
        session.commitComposition()

        #expect(narrowed == [swift])
        #expect(session.query == "swi")
        #expect(!session.isComposing)
        #expect(session.filteredBookmarks == [swift])
    }

    /// Each word is converted and added to the query, as 構造 and 計画
    @Test
    func conversionsAreAddedToTheQueryWordByWord() {
        var session = searchingSession()

        session.appendComposition("kouzou")
        session.beginConversion(["構造", "こうぞう", "コウゾウ"])
        let firstSelection = session.selectedConversion
        session.commitComposition()
        session.appendComposition("keikaku")
        session.beginConversion(["けいかく", "計画"])
        session.moveConversionSelection(by: 1)
        session.commitComposition()

        #expect(firstSelection == "構造")
        #expect(session.query == "構造計画")
        #expect(session.filteredBookmarks == [plan])
        #expect(session.selectedBookmark == plan)
    }

    @Test
    func escapeLeavesTheConversionThenTheComposition() {
        var session = searchingSession()
        session.appendComposition("kouzou")
        session.beginConversion(["構造"])

        session.cancelConversion()
        let stillComposing = session.isComposing
        session.cancelComposition()

        #expect(stillComposing)
        #expect(!session.isConverting)
        #expect(session.searchText.isEmpty)
        #expect(session.filteredBookmarks.count == 3)
    }

    @Test
    func backspaceDeletesTheCompositionBeforeTheQuery() {
        var session = searchingSession()
        session.appendComposition("sw")
        session.commitComposition()
        session.appendComposition("i")
        session.beginConversion(["い"])

        session.deleteBackward()
        let afterComposition = (session.query, session.composition, session.isConverting)
        session.deleteBackward()

        #expect(afterComposition == ("sw", "", false))
        #expect(session.query == "s")
    }

    @Test
    func noConversionIsListedWithoutAComposition() {
        var session = searchingSession()

        session.beginConversion(["構造"])

        #expect(!session.isConverting)
    }
}
