import Foundation

public struct SelectionPasteboardSnapshot: Equatable, Sendable {
    public let items: [[String: Data]]

    public init(items: [[String: Data]]) {
        self.items = items
    }
}

@MainActor
public protocol SelectionPasteboardClient: AnyObject {
    var changeCount: Int { get }
    func snapshot() throws -> SelectionPasteboardSnapshot
    func prepareForCopy() throws -> Int
    func copiedString() -> String?
    func restore(_ snapshot: SelectionPasteboardSnapshot) throws
}

@MainActor
public protocol SelectionCopySender {
    func sendCopy() -> Bool
}

public enum SelectionCaptureFailure: Error, Equatable, Sendable {
    case clipboardSnapshotFailed
    case clipboardPreparationFailed
    case copyUnavailable
    case pasteboardNotUpdated
    case copiedDataHasNoText
    case clipboardRestoreFailed
}

public enum SelectionCaptureResult: Equatable, Sendable {
    case success(String)
    case failure(SelectionCaptureFailure)
}

public struct SelectionCaptureService {
    public let timeoutNanoseconds: UInt64
    public let pollingNanoseconds: UInt64

    public init(
        timeoutNanoseconds: UInt64 = 700_000_000,
        pollingNanoseconds: UInt64 = 10_000_000
    ) {
        self.timeoutNanoseconds = timeoutNanoseconds
        self.pollingNanoseconds = pollingNanoseconds
    }

    @MainActor
    public func capture(
        pasteboard: any SelectionPasteboardClient,
        copySender: any SelectionCopySender
    ) async -> SelectionCaptureResult {
        let snapshot: SelectionPasteboardSnapshot
        do {
            snapshot = try pasteboard.snapshot()
        } catch {
            return .failure(.clipboardSnapshotFailed)
        }

        let baseline: Int
        do {
            baseline = try pasteboard.prepareForCopy()
        } catch {
            return .failure(.clipboardPreparationFailed)
        }

        let captureResult: SelectionCaptureResult
        if !copySender.sendCopy() {
            captureResult = .failure(.copyUnavailable)
        } else if await waitForPasteboardChange(
            pasteboard,
            after: baseline
        ) {
            if let text = pasteboard.copiedString(), !text.isEmpty {
                captureResult = .success(text)
            } else {
                captureResult = .failure(.copiedDataHasNoText)
            }
        } else {
            captureResult = .failure(.pasteboardNotUpdated)
        }

        do {
            try pasteboard.restore(snapshot)
        } catch {
            return .failure(.clipboardRestoreFailed)
        }
        return captureResult
    }

    @MainActor
    private func waitForPasteboardChange(
        _ pasteboard: any SelectionPasteboardClient,
        after baseline: Int
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + .nanoseconds(Int64(timeoutNanoseconds))
        while clock.now < deadline {
            if pasteboard.changeCount != baseline {
                return true
            }
            try? await Task.sleep(nanoseconds: pollingNanoseconds)
        }
        return pasteboard.changeCount != baseline
    }
}
