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

public enum DictionaryRegistrationInputField: Equatable, Sendable {
    case displayText
    case insertedText
}

/// Registration keeps the candidate display and the inserted text side by
/// side; an empty inserted text follows the display, so editing it starts
/// from an empty field
public struct DictionaryRegistrationSession: Equatable, Sendable {
    public let originalInput: String
    public let reading: String
    public private(set) var pastedCandidate: String?
    public private(set) var activeInputField = DictionaryRegistrationInputField
        .displayText
    private var confirmedDisplayText: String?
    private var confirmedInsertedText: String?

    public init(
        originalInput: String,
        reading: String,
        prefilledInsertedText: String? = nil
    ) {
        self.originalInput = originalInput
        self.reading = reading
        if let prefilledInsertedText, !prefilledInsertedText.isEmpty {
            confirmedInsertedText = prefilledInsertedText
        }
    }

    public var isInsertedTextCustomized: Bool {
        confirmedInsertedText != nil
    }

    /// Confirmed text of the field being edited
    public var confirmedCandidate: String? {
        switch activeInputField {
        case .displayText: confirmedDisplayText
        case .insertedText: confirmedInsertedText
        }
    }

    /// Display text including `pending` input when the display is edited
    public func displayText(pending: String? = nil) -> String {
        (confirmedDisplayText ?? "")
            + (activeInputField == .displayText ? pending ?? "" : "")
    }

    /// Text registered for insertion, which is the display while empty
    public func insertedText(pending: String? = nil) -> String {
        let editing = activeInputField == .insertedText
            ? (confirmedInsertedText ?? "") + (pending ?? "")
            : confirmedInsertedText ?? ""
        return editing.isEmpty ? displayText(pending: pending) : editing
    }

    /// Text shown in the inserted field; it is empty while being started
    public func visibleInsertedText(pending: String? = nil) -> String {
        guard activeInputField == .insertedText else {
            return insertedText(pending: pending)
        }
        return (confirmedInsertedText ?? "") + (pending ?? "")
    }

    public mutating func appendConfirmed(
        _ value: String,
        trailingSpace: Bool = false
    ) {
        let appended = value + (trailingSpace ? " " : "")
        updateActiveField { ($0 ?? "") + appended }
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
        guard let pastedCandidate else { return }
        updateActiveField {
            DictionaryRegistrationTextAccumulator.confirmedText(
                confirmed: $0,
                pendingPaste: pastedCandidate
            )
        }
        self.pastedCandidate = nil
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
        updateActiveField { _ in updated.isEmpty ? nil : updated }
        return true
    }

    /// Confirms `pending` into the current field and edits the other one
    public mutating func toggleInputField(absorbing pending: String?) {
        if let pending, !pending.isEmpty {
            appendConfirmed(pending)
        }
        pastedCandidate = nil
        activeInputField = activeInputField == .displayText
            ? .insertedText
            : .displayText
    }

    /// Pasted text needs no conversion, so it is confirmed while completing
    public mutating func completionAbsorbingPendingPaste()
        -> DictionaryRegistrationCompletion? {
        absorbPendingPaste()
        return completionWhenInputIsEmpty()
    }

    public func completionWhenInputIsEmpty()
        -> DictionaryRegistrationCompletion? {
        let display = displayText()
        let output = insertedText()
        guard pastedCandidate == nil,
              !display.isEmpty,
              !output.isEmpty else {
            return nil
        }
        return DictionaryRegistrationCompletion(
            reading: reading,
            output: output,
            display: display == output ? nil : display
        )
    }

    private mutating func updateActiveField(
        _ transform: (String?) -> String?
    ) {
        switch activeInputField {
        case .displayText:
            confirmedDisplayText = transform(confirmedDisplayText)
        case .insertedText:
            let updated = transform(confirmedInsertedText)
            confirmedInsertedText = updated?.isEmpty == false ? updated : nil
        }
    }
}
