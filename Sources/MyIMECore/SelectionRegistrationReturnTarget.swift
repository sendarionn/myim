/// The application a selection was registered from, returned to once the
/// registration succeeds. It is forgotten when the window closes, so the
/// next registration never returns to an earlier application
public struct SelectionRegistrationReturnTarget: Equatable, Sendable {
    public private(set) var processIdentifier: Int32?

    public init() {}

    /// Records the frontmost application when the service is called,
    /// before the registration window comes forward; myim itself or an
    /// unknown application is not returned to
    public mutating func begin(
        frontmostProcessIdentifier: Int32?,
        ownProcessIdentifier: Int32
    ) {
        guard let frontmostProcessIdentifier,
              frontmostProcessIdentifier > 0,
              frontmostProcessIdentifier != ownProcessIdentifier else {
            processIdentifier = nil
            return
        }
        processIdentifier = frontmostProcessIdentifier
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
