import Foundation
import Testing
@testable import MyIMECore

@Suite
struct InputHistoryStoreTests {
    @Test
    func keepsCommitsNewestFirstUpToTheLimit() {
        let store = InputHistoryStore(maximumCount: 3)
        for text in ["一", "", "二", "二", "三", "四"] {
            store.record(text: text)
        }
        // Empty text and the same text again are not added
        #expect(store.entries == ["四", "三", "二"])
        store.record(text: "三")
        #expect(store.entries == ["三", "四", "三"])
    }

    @Test
    func aSmallerLimitDropsTheOldest() {
        let store = InputHistoryStore()
        #expect(store.maximumCount == 10)
        (1...10).forEach { store.record(text: String($0)) }
        store.maximumCount = 4
        #expect(store.entries == ["10", "9", "8", "7"])
        store.maximumCount = 500
        #expect(store.maximumCount == 100)
        store.clear()
        #expect(store.entries.isEmpty)
    }

    @Test
    func theCountSettingIsTenUntilSetWithinOneToAHundred() {
        let defaults = UserDefaults(suiteName: "InputHistoryStoreTests")!
        defaults.removePersistentDomain(forName: "InputHistoryStoreTests")
        defer { defaults.removePersistentDomain(forName: "InputHistoryStoreTests") }
        let settings = InputFeatureSettings(defaults: defaults)
        #expect(settings.inputHistoryMaximumCount == 10)
        settings.inputHistoryMaximumCount = 0
        #expect(settings.inputHistoryMaximumCount == 1)
        settings.inputHistoryMaximumCount = 30
        #expect(settings.inputHistoryMaximumCount == 30)
    }
}
