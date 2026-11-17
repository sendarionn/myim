import Foundation
import MyIMECore

// Chrome starts this host for each sync from the myim extension and passes
// one native messaging frame on standard input. The bookmarks stay on this
// Mac and are never written to the log

private func readExactly(_ count: Int) -> Data? {
    var data = Data()
    while data.count < count {
        let chunk = FileHandle.standardInput.readData(
            ofLength: count - data.count
        )
        guard !chunk.isEmpty else { return nil }
        data.append(chunk)
    }
    return data
}

private func reply(_ reply: BookmarkSyncReply) {
    guard let payload = try? JSONEncoder().encode(reply) else { return }
    FileHandle.standardOutput.write(NativeMessagingFrame.encode(payload))
}

while let header = readExactly(4) {
    guard let length = NativeMessagingFrame.length(ofHeader: header),
          let payload = readExactly(length) else {
        reply(BookmarkSyncReply(ok: false, error: "invalid-frame"))
        exit(1)
    }
    // Tests point the host at a directory of their own
    let override = ProcessInfo.processInfo.environment["MYIM_BOOKMARK_DIRECTORY"]
    guard let directory = override.map({ URL(fileURLWithPath: $0) })
        ?? SyncedBookmarkStore.defaultDirectory else {
        reply(BookmarkSyncReply(ok: false, error: "no-data-directory"))
        continue
    }
    do {
        let message = try JSONDecoder().decode(
            BookmarkSyncMessage.self,
            from: payload
        )
        try SyncedBookmarkStore(directory: directory).replace(with: message)
        reply(BookmarkSyncReply(ok: true, count: message.bookmarks.count))
    } catch SyncedBookmarkStore.StoreError.invalidProfileID {
        reply(BookmarkSyncReply(ok: false, error: "invalid-profile-id"))
    } catch is DecodingError {
        reply(BookmarkSyncReply(ok: false, error: "invalid-message"))
    } catch {
        reply(BookmarkSyncReply(ok: false, error: "write-failed"))
    }
}
