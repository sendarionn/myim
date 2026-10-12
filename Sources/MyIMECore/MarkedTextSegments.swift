/// UTF-16 ranges of the text being converted and the trailing part that
/// waits for the next conversion, so the two can be marked separately
public struct MarkedTextSegments: Equatable, Sendable {
    public let target: Range<Int>
    public let pending: Range<Int>

    public init(target: Range<Int>, pending: Range<Int>) {
        self.target = target
        self.pending = pending
    }

    /// Nil when there is no pending part or nothing before it
    public init?(text: String, pendingSuffix: String) {
        guard !pendingSuffix.isEmpty,
              text.hasSuffix(pendingSuffix) else {
            return nil
        }
        let total = text.utf16.count
        let boundary = total - pendingSuffix.utf16.count
        guard boundary > 0 else { return nil }
        self.init(target: 0..<boundary, pending: boundary..<total)
    }
}
