import Foundation
import Testing
@testable import MyIMECore

@Suite
struct CandidateSelectionHistoryStoreTests {
    @Test
    func recordsAndPersistsOneCoherentHistorySnapshot() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CandidateSelectionHistoryStore(
            history: CandidateSelectionHistory(),
            writer: DeferredJSONFileWriter(
                fileURL: fileURL,
                delay: 60,
                queueLabel: "myim.history-store-test"
            )
        )

        store.record("候補", readings: ["kouho"])
        store.flush()

        let saved = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: Data(contentsOf: fileURL)
        )
        #expect(store.candidates(for: ["kouho"]) == ["候補"])
        #expect(saved.candidates(for: ["kouho"]) == ["候補"])
        #expect(store.containsAny(["候補"]))
    }

    @Test
    func removalUpdatesQueriesAndThePersistedSnapshotTogether() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        var history = CandidateSelectionHistory()
        history.record("候補", readings: ["kouho"])
        let store = CandidateSelectionHistoryStore(
            history: history,
            writer: DeferredJSONFileWriter(
                fileURL: fileURL,
                delay: 60,
                queueLabel: "myim.history-store-removal-test"
            )
        )

        store.remove(["候補"])
        store.flush()

        let saved = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: Data(contentsOf: fileURL)
        )
        #expect(store.candidates(for: ["kouho"]).isEmpty)
        #expect(saved.candidates(for: ["kouho"]).isEmpty)
        #expect(!store.containsAny(["候補"]))
    }
}
