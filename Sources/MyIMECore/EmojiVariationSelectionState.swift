import Foundation

public enum EmojiVariationPresentationAction: Equatable, Sendable {
    case schedule(baseCode: String, generation: Int)
    case show(baseCode: String)
    case keep
    case hide
}

public struct EmojiVariationSelectionState: Equatable, Sendable {
    public static let automaticPresentationDelay: TimeInterval = 0.3

    public private(set) var presentedBaseCode: String?
    public private(set) var pendingBaseCode: String?
    public private(set) var pendingGeneration: Int?
    public private(set) var suppressedBaseCode: String?
    private var nextGeneration = 0

    public init() {}

    public mutating func selectionChanged(
        to baseCode: String?,
        presentsImmediately: Bool = false
    ) -> EmojiVariationPresentationAction {
        guard let baseCode else {
            presentedBaseCode = nil
            pendingBaseCode = nil
            pendingGeneration = nil
            suppressedBaseCode = nil
            return .hide
        }
        if presentsImmediately, suppressedBaseCode == baseCode {
            suppressedBaseCode = nil
        }
        guard suppressedBaseCode != baseCode else {
            presentedBaseCode = nil
            pendingBaseCode = nil
            pendingGeneration = nil
            return .hide
        }
        guard presentedBaseCode != baseCode else {
            pendingBaseCode = nil
            pendingGeneration = nil
            return .keep
        }
        if presentsImmediately {
            presentedBaseCode = baseCode
            pendingBaseCode = nil
            pendingGeneration = nil
            suppressedBaseCode = nil
            return .show(baseCode: baseCode)
        }
        guard pendingBaseCode != baseCode else {
            return .keep
        }
        presentedBaseCode = nil
        pendingBaseCode = baseCode
        nextGeneration += 1
        pendingGeneration = nextGeneration
        suppressedBaseCode = nil
        return .schedule(
            baseCode: baseCode,
            generation: nextGeneration
        )
    }

    public mutating func scheduledPresentationFired(
        for baseCode: String,
        generation: Int
    ) -> Bool {
        guard pendingBaseCode == baseCode,
              pendingGeneration == generation,
              suppressedBaseCode != baseCode else { return false }
        presentedBaseCode = baseCode
        pendingBaseCode = nil
        pendingGeneration = nil
        suppressedBaseCode = nil
        return true
    }

    public mutating func cancelPendingPresentation() {
        pendingBaseCode = nil
        pendingGeneration = nil
    }

    public mutating func dismissCurrent() {
        suppressedBaseCode = presentedBaseCode
        presentedBaseCode = nil
        pendingBaseCode = nil
        pendingGeneration = nil
    }

    public mutating func reset() {
        presentedBaseCode = nil
        pendingBaseCode = nil
        pendingGeneration = nil
        suppressedBaseCode = nil
    }
}
