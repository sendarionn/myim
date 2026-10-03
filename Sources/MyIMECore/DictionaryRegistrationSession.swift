public struct DictionaryRegistrationCompletion: Equatable, Sendable {
    public let reading: String
    public let output: String
    public let display: String?

    public init(reading: String, output: String, display: String?) {
        self.reading = reading
        self.output = output
        self.display = display
    }
}

public struct DictionaryRegistrationSession: Equatable, Sendable {
    public let originalInput: String
    public let reading: String
    public private(set) var pastedCandidate: String?
    public private(set) var confirmedCandidate: String?
    public private(set) var outputCandidate: String?

    public init(originalInput: String, reading: String) {
        self.originalInput = originalInput
        self.reading = reading
    }

    public var isEnteringDisplayName: Bool {
        outputCandidate != nil
    }

    public mutating func appendConfirmed(
        _ value: String,
        trailingSpace: Bool = false
    ) {
        confirmedCandidate = (confirmedCandidate ?? "")
            + value
            + (trailingSpace ? " " : "")
        pastedCandidate = nil
    }

    public mutating func appendSpace() {
        appendConfirmed(" ")
    }

    public mutating func replacePendingPaste(with value: String) {
        absorbPendingPaste()
        pastedCandidate = value
    }

    public mutating func absorbPendingPaste() {
        confirmedCandidate = DictionaryRegistrationTextAccumulator
            .confirmedText(
                confirmed: confirmedCandidate,
                pendingPaste: pastedCandidate
            )
        pastedCandidate = nil
    }

    public mutating func discardPendingPaste() {
        pastedCandidate = nil
    }

    @discardableResult
    public mutating func deleteBackwardFromConfirmed(
        unit: InputBufferDeletionUnit
    ) -> Bool {
        guard let confirmedCandidate, !confirmedCandidate.isEmpty else {
            return false
        }
        let updated = InputBufferDeletion.deletingBackward(
            from: confirmedCandidate,
            unit: unit
        )
        self.confirmedCandidate = updated.isEmpty ? nil : updated
        return true
    }

    @discardableResult
    public mutating func beginDisplayName(output: String) -> Bool {
        guard !isEnteringDisplayName, !output.isEmpty else { return false }
        outputCandidate = output
        confirmedCandidate = nil
        pastedCandidate = nil
        return true
    }

    public func completionWhenInputIsEmpty()
        -> DictionaryRegistrationCompletion? {
        guard pastedCandidate == nil,
              let confirmedCandidate,
              !confirmedCandidate.isEmpty else {
            return nil
        }
        return DictionaryRegistrationCompletion(
            reading: reading,
            output: outputCandidate ?? confirmedCandidate,
            display: outputCandidate == nil ? nil : confirmedCandidate
        )
    }
}
