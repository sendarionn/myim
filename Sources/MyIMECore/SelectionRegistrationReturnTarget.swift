/// The application a selection was registered from, returned to once the
/// registration succeeds. It is forgotten when the window closes, so the
/// next registration never returns to an earlier application
public struct SelectionRegistrationReturnTarget: Equatable, Sendable {
    public private(set) var processIdentifier: Int32?

    public init() {}

    /// Records the application the service was called from, before the
    /// registration window comes forward. The service is already the
    /// frontmost application when it is called, so the candidates are
    /// tried in order, such as the frontmost application, the menu bar
    /// owner, and the owner of the frontmost window; myim itself or an
    /// unknown application is not returned to
    public mutating func begin(
        candidateProcessIdentifiers: [Int32?],
        ownProcessIdentifier: Int32
    ) {
        processIdentifier = candidateProcessIdentifiers.lazy
            .compactMap { $0 }
            .first { $0 > 0 && $0 != ownProcessIdentifier }
    }

    /// The application to return to after a successful registration,
    /// given only once
    public mutating func takeAfterRegistration() -> Int32? {
        defer { processIdentifier = nil }
        return processIdentifier
    }

    public mutating func clear() {
        processIdentifier = nil
    }
}
