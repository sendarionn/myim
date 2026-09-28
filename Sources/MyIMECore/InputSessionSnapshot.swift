public struct InputSessionSnapshot: Equatable, Sendable {
    public let sessionGeneration: UInt
    public let inputRevision: UInt

    public init(sessionGeneration: UInt, inputRevision: UInt) {
        self.sessionGeneration = sessionGeneration
        self.inputRevision = inputRevision
    }

    public func isCurrent(
        sessionGeneration: UInt?,
        inputRevision: UInt
    ) -> Bool {
        sessionGeneration == self.sessionGeneration
            && inputRevision == self.inputRevision
    }
}
