public enum EmojiVariationPresentationAction: Equatable, Sendable {
    case show(baseCode: String)
    case keep
    case hide
}

public struct EmojiVariationSelectionState: Equatable, Sendable {
    public private(set) var presentedBaseCode: String?
    public private(set) var suppressedBaseCode: String?

    public init() {}

    public mutating func selectionChanged(
        to baseCode: String?,
        reopensSuppressed: Bool = false
    ) -> EmojiVariationPresentationAction {
        guard let baseCode else {
            presentedBaseCode = nil
            suppressedBaseCode = nil
            return .hide
        }
        if reopensSuppressed, suppressedBaseCode == baseCode {
            suppressedBaseCode = nil
        }
        guard suppressedBaseCode != baseCode else {
            presentedBaseCode = nil
            return .hide
        }
        guard presentedBaseCode != baseCode else {
            return .keep
        }
        presentedBaseCode = baseCode
        suppressedBaseCode = nil
        return .show(baseCode: baseCode)
    }

    public mutating func dismissCurrent() {
        suppressedBaseCode = presentedBaseCode
        presentedBaseCode = nil
    }

    public mutating func reset() {
        presentedBaseCode = nil
        suppressedBaseCode = nil
    }
}
