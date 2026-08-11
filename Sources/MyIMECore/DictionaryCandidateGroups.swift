public struct DictionaryCandidateGroups: Equatable, Sendable {
    public let exact: [String]
    public let prefix: [String]

    public init(exact: [String] = [], prefix: [String] = []) {
        self.exact = exact
        self.prefix = prefix
    }

    public var all: [String] {
        exact + prefix
    }
}
