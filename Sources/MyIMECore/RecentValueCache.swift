/// Values computed for the latest keys, forgetting the oldest beyond
/// `capacity`; for main-thread lookups that are asked again with the same
/// key, such as a refresh of the same input
public final class RecentValueCache<Key: Hashable, Value> {
    private let capacity: Int
    private var values: [Key: Value] = [:]
    private var order: [Key] = []

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    public func value(for key: Key, compute: () -> Value) -> Value {
        if let value = values[key] {
            return value
        }
        let value = compute()
        values[key] = value
        order.append(key)
        if order.count > capacity {
            values[order.removeFirst()] = nil
        }
        return value
    }
}
