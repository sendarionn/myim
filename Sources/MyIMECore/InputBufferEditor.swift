public struct InputBufferEditor: Equatable, Sendable {
    public private(set) var value: String
    public private(set) var cursor: Int

    public init(value: String = "", cursor: Int? = nil) {
        self.value = value
        self.cursor = min(max(cursor ?? value.count, 0), value.count)
    }

    public mutating func insert(_ text: String) {
        let index = value.index(value.startIndex, offsetBy: cursor)
        value.insert(contentsOf: text, at: index)
        cursor += text.count
    }

    @discardableResult
    public mutating func move(by offset: Int) -> Bool {
        let next = min(max(cursor + offset, 0), value.count)
        guard next != cursor else { return false }
        cursor = next
        return true
    }

    public mutating func deleteBackward(unit: InputBufferDeletionUnit) {
        if case .all = unit {
            value = ""
            cursor = 0
            return
        }
        guard cursor > 0 else { return }
        let prefixEnd = value.index(value.startIndex, offsetBy: cursor)
        let prefix = String(value[..<prefixEnd])
        let updatedPrefix = InputBufferDeletion.deletingBackward(
            from: prefix,
            unit: unit
        )
        value = updatedPrefix + value[prefixEnd...]
        cursor = updatedPrefix.count
    }
}
