import Foundation
import Testing
@testable import MyIMECore

@Suite
struct PersistedFileTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test
    func noFileIsNoData() throws {
        let url = try directory().appendingPathComponent("history.json")
        guard case .missing = PersistedFile.load(from: url, decode: { _ in 1 }) else {
            Issue.record("a missing file is no data")
            return
        }
    }

    @Test
    func aFileThatCannotBeDecodedIsKeptAside() throws {
        let url = try directory().appendingPathComponent("history.json")
        try Data("{broken".utf8).write(to: url)
        let load = PersistedFile.load(from: url, decode: { _ -> Int? in nil })
        guard case let .unreadable(preserved?) = load else {
            Issue.record("the unreadable file is copied aside")
            return
        }
        #expect(try Data(contentsOf: preserved) == Data("{broken".utf8))
        #expect(preserved.lastPathComponent.hasPrefix("history.unreadable-"))
        #expect(preserved.pathExtension == "json")
    }

    @Test
    func aReadableFileIsLoaded() throws {
        let url = try directory().appendingPathComponent("history.json")
        try Data("7".utf8).write(to: url)
        guard case .loaded(7) = PersistedFile.load(from: url, decode: {
            Int(String(decoding: $0, as: UTF8.self))
        }) else {
            Issue.record("the value is loaded")
            return
        }
    }
}
