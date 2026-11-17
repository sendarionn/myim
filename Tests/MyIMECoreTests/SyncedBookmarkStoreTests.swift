import Foundation
import Testing
@testable import MyIMECore

@Suite
struct SyncedBookmarkStoreTests {
    private func temporaryStore() -> SyncedBookmarkStore {
        SyncedBookmarkStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString))
    }

    private func message(
        _ profileID: String,
        _ profileName: String,
        _ titles: [String]
    ) -> BookmarkSyncMessage {
        BookmarkSyncMessage(
            profileID: profileID,
            profileName: profileName,
            bookmarks: titles.map {
                .init(
                    title: $0,
                    url: "https://example.com/\($0)",
                    folderPath: "ブックマーク バー"
                )
            }
        )
    }

    @Test
    func tellsNothingSyncedFromAnEmptyList() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        #expect(store.load() == .notSynced)

        try store.replace(with: message("p1", "Work", []))

        #expect(store.load() == .synced([]))
    }

    /// Syncing a second profile keeps the first; syncing a profile again
    /// replaces only its own list, so removed bookmarks disappear
    @Test
    func replacesEachProfileOnItsOwn() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        try store.replace(with: message("p1", "Work", ["a", "b"]))
        try store.replace(with: message("p2", "Home", ["c"]))
        try store.replace(with: message("p1", "Work", ["b"]))

        guard case let .synced(bookmarks) = store.load() else {
            Issue.record("not synced")
            return
        }
        #expect(bookmarks.map(\.title).sorted() == ["b", "c"])
        #expect(bookmarks.first { $0.title == "c" }?.profile == "Home")
        #expect(bookmarks.first { $0.title == "b" }?.folderPath
            == "ブックマーク バー")
    }

    @Test(arguments: ["", "../x", "a/b", "p 1", String(repeating: "a", count: 65)])
    func refusesProfileIDsThatAreNotPlainNames(id: String) {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        #expect(throws: SyncedBookmarkStore.StoreError.invalidProfileID) {
            try store.replace(with: message(id, "Work", ["a"]))
        }
    }

    @Test
    func framesMessagesAsChromeDoes() {
        let frame = NativeMessagingFrame.encode(Data("{}".utf8))

        #expect(frame.prefix(4) == Data([2, 0, 0, 0]))
        #expect(NativeMessagingFrame.length(ofHeader: frame.prefix(4)) == 2)
        #expect(NativeMessagingFrame.length(
            ofHeader: Data([0xff, 0xff, 0xff, 0xff])
        ) == nil)
    }

    /// The three reasons the panel shows no bookmark
    @Test
    func explainsWhyNoBookmarkIsListed() {
        var notSynced = BookmarkSearchSession()
        notSynced.begin()
        notSynced.failLoading(BookmarkSearchSession.notSyncedMessage)

        var empty = BookmarkSearchSession()
        empty.begin()
        empty.replaceBookmarks([])

        var unmatched = BookmarkSearchSession()
        unmatched.begin()
        unmatched.replaceBookmarks([BrowserBookmark(
            title: "myim",
            url: "https://example.com",
            folderPath: "",
            profile: "Work"
        )])
        unmatched.updateQuery("zzz")

        #expect(notSynced.emptyMessage == BookmarkSearchSession.notSyncedMessage)
        #expect(empty.emptyMessage == BookmarkSearchSession.syncedButEmptyMessage)
        #expect(unmatched.emptyMessage == "「zzz」に一致するブックマークがありません")
    }
}
