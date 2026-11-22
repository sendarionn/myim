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

    // MARK: Searching with the normal conversion

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

    /// ASCII narrows the list while it is still being typed, as before
    @Test
    func inputBeingTypedNarrowsTheList() {
        var session = searchingSession()

        session.setComposition("swi")

        #expect(session.filteredBookmarks == [swift])
        #expect(session.searchText == "swi")
        #expect(session.query.isEmpty)
    }

    /// Words the conversion commits build the query, as 構造 and 計画
    @Test
    func committedConversionsBuildTheQuery() {
        var session = searchingSession()

        session.setComposition("kouzou")
        session.setComposition("")
        session.appendToQuery("構造")
        session.setComposition("keikaku")
        let whileTyping = session.filteredBookmarks
        session.setComposition("")
        session.appendToQuery("計画")

        #expect(whileTyping.isEmpty)
        #expect(session.query == "構造計画")
        #expect(session.filteredBookmarks == [plan])
        #expect(session.selectedBookmark == plan)
    }

    @Test
    func backspaceDeletesFromTheQuery() {
        var session = searchingSession()
        session.appendToQuery("swi")

        session.deleteBackward()

        #expect(session.query == "sw")
    }

    @Test
    func nothingIsComposedOnceTheSearchEnds() {
        var session = searchingSession()
        session.setComposition("kouzou")

        session.reset()
        session.setComposition("ki")

        #expect(session.composition.isEmpty)
        #expect(!session.isComposing)
    }
}
