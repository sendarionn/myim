import Foundation
import Testing
@testable import MyIMECore

@Suite
struct DeferredJSONFileWriterTests {
    @Test
    func flushesOnlyTheLatestScheduledValue() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("history.json")
        let writer = DeferredJSONFileWriter<[String: Int]>(
            fileURL: fileURL,
            delay: 60,
            queueLabel: "myim.tests.deferred-writer"
        )

        writer.schedule(["古い": 1])
        writer.schedule(["新しい": 2])
        writer.flush()

        let data = try Data(contentsOf: fileURL)
        let value = try JSONDecoder().decode([String: Int].self, from: data)
        #expect(value == ["新しい": 2])
    }

    @Test
    func immediateWriteReplacesPendingValue() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("model.json")
        let writer = DeferredJSONFileWriter<[String]>(
            fileURL: fileURL,
            delay: 60,
            queueLabel: "myim.tests.immediate-writer"
        )

        writer.schedule(["保存しない"])
        try writer.writeImmediately(["保存する"])
        writer.flush()

        let data = try Data(contentsOf: fileURL)
        let value = try JSONDecoder().decode([String].self, from: data)
        #expect(value == ["保存する"])
    }
}
