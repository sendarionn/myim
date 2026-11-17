import Foundation

/// A message Chrome's native messaging carries: a 32-bit length in the
/// machine's byte order, little-endian on every Mac, then UTF-8 JSON
public enum NativeMessagingFrame {
    /// Chrome sends at most 64 MiB to a native host
    public static let maximumLength = 64 * 1024 * 1024

    public static func encode(_ payload: Data) -> Data {
        var length = UInt32(payload.count).littleEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(payload)
        return frame
    }

    /// The payload length from the first four bytes of a frame
    public static func length(ofHeader header: Data) -> Int? {
        guard header.count == 4 else { return nil }
        let length = header.withUnsafeBytes {
            UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self))
        }
        let value = Int(length)
        return value <= maximumLength ? value : nil
    }
}

/// The bookmarks of one Chrome profile as the extension sends them; the
/// whole list replaces the profile's previous one
public struct BookmarkSyncMessage: Codable, Equatable, Sendable {
    public struct Bookmark: Codable, Equatable, Sendable {
        public let title: String
        public let url: String
        public let folderPath: String

        public init(title: String, url: String, folderPath: String) {
            self.title = title
            self.url = url
            self.folderPath = folderPath
        }
    }

    public static let replaceType = "replaceBookmarks"

    public let type: String
    public let profileID: String
    public let profileName: String
    public let bookmarks: [Bookmark]

    public init(
        profileID: String,
        profileName: String,
        bookmarks: [Bookmark]
    ) {
        type = Self.replaceType
        self.profileID = profileID
        self.profileName = profileName
        self.bookmarks = bookmarks
    }
}

public struct BookmarkSyncReply: Codable, Equatable, Sendable {
    public let ok: Bool
    public let count: Int
    public let error: String?

    public init(ok: Bool, count: Int = 0, error: String? = nil) {
        self.ok = ok
        self.count = count
        self.error = error
    }
}

/// The bookmarks Chrome extensions have synced, one file per profile, so
/// syncing one profile never replaces another and the list stays
/// searchable while Chrome is closed
public struct SyncedBookmarkStore: Sendable {
    public enum Contents: Equatable, Sendable {
        /// No profile has synced yet
        case notSynced
        case synced([BrowserBookmark])
    }

    public enum StoreError: Error, Equatable {
        case invalidMessage
        case invalidProfileID
    }

    private struct ProfileFile: Codable {
        let version: Int
        let profileID: String
        let profileName: String
        let syncedAt: Date
        let bookmarks: [BookmarkSyncMessage.Bookmark]
    }

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static var defaultDirectory: URL? {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("myim", isDirectory: true)
            .appendingPathComponent("bookmarks", isDirectory: true)
    }

    /// Replaces the profile's list as a whole, atomically
    public func replace(with message: BookmarkSyncMessage, now: Date = Date())
        throws {
        guard message.type == BookmarkSyncMessage.replaceType else {
            throw StoreError.invalidMessage
        }
        guard Self.isValidProfileID(message.profileID) else {
            throw StoreError.invalidProfileID
        }
        let bookmarks = message.bookmarks.filter { !$0.url.isEmpty }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let file = directory.appendingPathComponent(
            message.profileID + ".json"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(ProfileFile(
            version: 1,
            profileID: message.profileID,
            profileName: message.profileName,
            syncedAt: now,
            bookmarks: bookmarks
        )).write(to: file, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: file.path
        )
    }

    /// Every synced profile's bookmarks; a file that cannot be read is
    /// skipped so one broken profile does not hide the others
    public func load() -> Contents {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return .notSynced
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var profiles: [ProfileFile] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let profile = try? decoder.decode(
                    ProfileFile.self,
                    from: data
                  ) else { continue }
            profiles.append(profile)
        }
        guard !profiles.isEmpty else { return .notSynced }
        var seen = Set<BrowserBookmark>()
        var bookmarks: [BrowserBookmark] = []
        for profile in profiles.sorted(by: {
            ($0.profileName, $0.profileID) < ($1.profileName, $1.profileID)
        }) {
            for bookmark in profile.bookmarks {
                let item = BrowserBookmark(
                    title: bookmark.title,
                    url: bookmark.url,
                    folderPath: bookmark.folderPath,
                    profile: profile.profileName
                )
                if seen.insert(item).inserted {
                    bookmarks.append(item)
                }
            }
        }
        return .synced(bookmarks)
    }

    /// Profile IDs become file names, so only plain letters, digits, and
    /// hyphens are taken
    static func isValidProfileID(_ id: String) -> Bool {
        (1...64).contains(id.count)
            && id.unicodeScalars.allSatisfy {
                ($0.isASCII && CharacterSet.alphanumerics.contains($0))
                    || $0 == "-"
            }
    }
}
