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

    /// A value slow to encode stands in for a large model on a busy disk
    private struct SlowValue: Encodable, Sendable {
        let milliseconds: UInt32

        func encode(to encoder: Encoder) throws {
            usleep(milliseconds * 1_000)
            var container = encoder.singleValueContainer()
            try container.encode("written")
        }
    }

    /// Switching applications flushes on the main thread, which must not
    /// wait for the write, while the value still reaches the file
    @Test
    func backgroundFlushDoesNotWaitForTheWrite() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("slow.json")
        let writer = DeferredJSONFileWriter<SlowValue>(
            fileURL: file,
            delay: 60,
            queueLabel: "test.background-flush"
        )
        writer.schedule(SlowValue(milliseconds: 500))

        let start = ContinuousClock.now
        writer.flushInBackground()
        let waited = ContinuousClock.now - start

        #expect(waited < .milliseconds(100))
        #expect(!FileManager.default.fileExists(atPath: file.path))

        writer.flush()

        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test
    func backgroundFlushWithNothingPendingDoesNothing() {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("none.json")
        let writer = DeferredJSONFileWriter<SlowValue>(
            fileURL: file,
            delay: 60,
            queueLabel: "test.background-flush-empty"
        )

        writer.flushInBackground()
        writer.flush()

        #expect(!FileManager.default.fileExists(atPath: file.path))
    }
}
