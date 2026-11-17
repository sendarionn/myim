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
}
