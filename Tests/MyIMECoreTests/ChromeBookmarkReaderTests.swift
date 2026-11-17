import Foundation
import Testing
@testable import MyIMECore

@Suite
struct ChromeBookmarkReaderTests {
    @Test
    func readsExistingBookmarkFilesAcrossProfilesWithFolderPaths() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Default"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Profile 1"),
            withIntermediateDirectories: true
        )
        try Data(#"{"profile":{"info_cache":{"Default":{"name":"個人"},"Profile 1":{"name":"仕事"}}}}"#.utf8)
            .write(to: root.appendingPathComponent("Local State"))
        try bookmarkData(
            title: "Swift",
            url: "https://swift.org",
            folder: "開発"
        ).write(to: root.appendingPathComponent("Default/Bookmarks"))
        try bookmarkData(
            title: "Issue",
            url: "https://example.com/issues",
            folder: "案件"
        ).write(to: root.appendingPathComponent("Profile 1/AccountBookmarks"))

        let bookmarks = try ChromeBookmarkReader().bookmarks(in: root)

        #expect(bookmarks == [
            BrowserBookmark(
                title: "Swift",
                url: "https://swift.org",
                folderPath: "ブックマーク / 開発",
                profile: "個人"
            ),
            BrowserBookmark(
                title: "Issue",
                url: "https://example.com/issues",
                folderPath: "ブックマーク / 案件",
                profile: "仕事"
            )
        ])
    }

    @Test
    func rereadsChangedFilesAndDeduplicatesOverlappingStores() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let profile = root.appendingPathComponent("Default")
        try FileManager.default.createDirectory(
            at: profile,
            withIntermediateDirectories: true
        )
        let original = try bookmarkData(
            title: "Original",
            url: "https://example.com",
            folder: "保存"
        )
        try original.write(to: profile.appendingPathComponent("Bookmarks"))
        try original.write(to: profile.appendingPathComponent("AccountBookmarks"))
        #expect(try ChromeBookmarkReader().bookmarks(in: root).count == 1)

        try bookmarkData(
            title: "Updated",
            url: "https://example.com/updated",
            folder: "保存"
        ).write(to: profile.appendingPathComponent("Bookmarks"))

        let reread = try ChromeBookmarkReader().bookmarks(in: root)
        #expect(reread.map(\.title) == ["Updated", "Original"])
    }

    @Test
    func skipsAnUnreadableOrMalformedStoreWithoutLosingOtherProfiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let brokenProfile = root.appendingPathComponent("Default")
        let validProfile = root.appendingPathComponent("Profile 1")
        try FileManager.default.createDirectory(
            at: brokenProfile,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: validProfile,
            withIntermediateDirectories: true
        )
        try Data("not json".utf8)
            .write(to: brokenProfile.appendingPathComponent("Bookmarks"))
        try bookmarkData(
            title: "Available",
            url: "https://example.com/available",
            folder: "保存"
        ).write(to: validProfile.appendingPathComponent("Bookmarks"))

        let bookmarks = try ChromeBookmarkReader().bookmarks(in: root)

        #expect(bookmarks.map(\.title) == ["Available"])
    }

    private func bookmarkData(
        title: String,
        url: String,
        folder: String
    ) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "roots": [
                "bookmark_bar": [
                    "type": "folder",
                    "name": "ブックマーク",
                    "children": [[
                        "type": "folder",
                        "name": folder,
                        "children": [[
                            "type": "url",
                            "name": title,
                            "url": url
                        ]]
                    ]]
                ]
            ]
        ])
    }
}
