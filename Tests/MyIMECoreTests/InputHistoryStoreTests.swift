import Foundation
import Testing
@testable import MyIMECore

@Suite
struct InputHistoryStoreTests {
    /// The last four commits are kept, newest first; empty text and the
    /// same text again are not added
    @Test
    func keepsTheLastFourCommitsNewestFirst() {
        let store = InputHistoryStore()
        for text in ["一", "", "二", "二", "三", "四", "五"] {
            store.record(text: text)
        }
        #expect(store.entries == ["五", "四", "三", "二"])
        store.record(text: "三")
        #expect(store.entries == ["三", "五", "四", "三"])
        store.clear()
        #expect(store.entries.isEmpty)
    }

    /// A count kept by an earlier version is not read
    @Test
    func anEarlierCountSettingIsIgnored() {
        let defaults = UserDefaults(suiteName: "InputHistoryStoreTests")!
        defer { defaults.removePersistentDomain(forName: "InputHistoryStoreTests") }
        defaults.set(30, forKey: "InputHistoryMaximumCount")
        let store = InputHistoryStore()
        (1...10).forEach { store.record(text: String($0)) }
        #expect(store.entries.count == InputHistoryStore.maximumCount)
        #expect(InputHistoryStore.maximumCount == 4)
    }
}
