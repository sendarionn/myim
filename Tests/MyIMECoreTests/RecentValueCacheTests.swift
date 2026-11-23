import Testing
@testable import MyIMECore

@Suite
struct RecentValueCacheTests {
    @Test
    func theSameKeyIsComputedOnce() {
        let cache = RecentValueCache<String, Int>(capacity: 2)
        var computed = 0
        _ = cache.value(for: "a") { computed += 1; return 1 }
        #expect(cache.value(for: "a") { computed += 1; return 2 } == 1)
        #expect(computed == 1)
    }

    @Test
    func theOldestKeyIsForgottenBeyondCapacity() {
        let cache = RecentValueCache<String, Int>(capacity: 2)
        _ = cache.value(for: "a") { 1 }
        _ = cache.value(for: "b") { 2 }
        _ = cache.value(for: "c") { 3 }
        #expect(cache.value(for: "a") { 10 } == 10)
        #expect(cache.value(for: "c") { 30 } == 3)
    }
}
