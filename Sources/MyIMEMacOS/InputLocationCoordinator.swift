@preconcurrency import AppKit
import InputMethodKit
import MyIMECore
import OSLog

final class InputLocationCoordinator {
    private let logger: Logger
    private var anchorSession = InputLocationAnchorSession<NSRect>()
    private var candidateRetry: DispatchWorkItem?

    init(logger: Logger) {
        self.logger = logger
    }

    deinit {
        candidateRetry?.cancel()
    }

    var compositionAnchorDescription: String {
        anchorSession.compositionAnchor.map(String.init(describing:)) ?? "nil"
    }

    var lastValidLocationDescription: String {
        anchorSession.lastValidLocation.map(String.init(describing:)) ?? "nil"
    }

    func captureCompositionAnchor(from sender: Any) {
        anchorSession.captureCompositionAnchor(query(sender))
    }

    func clearCompositionAnchor() {
        anchorSession.clearCompositionAnchor()
    }

    func forgetPreviousLocation() {
        anchorSession.forgetPreviousLocation()
    }

    func inputLocation(for sender: Any) -> NSRect {
        let result = query(sender)
        let location = anchorSession.fallbackLocation(after: result)
        if result.location == nil {
            logger.notice(
                "invalid input location reusedPrevious=\(location != nil, privacy: .public)"
            )
        }
        return location ?? .zero
    }

    func candidateAnchor(
        for sender: Any
    ) -> CandidateAnchorResolution<NSRect> {
        let anchor = anchorSession.candidateAnchor(after: query(sender))
        switch anchor {
        case let .current(frame):
            logger.notice(
                "candidate anchor source=current frame=\(String(describing: frame), privacy: .public)"
            )
        case .deferredAfterPlaceholder:
            logger.notice(
                "candidate anchor deferred after rejecting placeholder"
            )
        case let .composition(frame):
            logger.notice(
                "candidate anchor source=composition frame=\(String(describing: frame), privacy: .public)"
            )
        case let .previous(frame):
            logger.notice(
                "candidate anchor source=previous frame=\(String(describing: frame), privacy: .public)"
            )
        case .missing:
            logger.notice("candidate anchor source=missing")
        }
        return anchor
    }

    func scheduleCandidateRetry(
        isCurrent: @escaping () -> Bool,
        retry: @escaping () -> Void
    ) {
        guard candidateRetry == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            candidateRetry = nil
            guard isCurrent() else {
                anchorSession.resetRetryAttempts()
                return
            }
            let attempt = anchorSession.beginRetryAttempt()
            if attempt == 1 || attempt.isMultiple(of: 10) {
                logger.notice(
                    "retrying candidate location attempt=\(attempt, privacy: .public)"
                )
            }
            retry()
        }
        candidateRetry = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + anchorSession.nextRetryDelay,
            execute: workItem
        )
    }

    func cancelCandidateRetry() {
        candidateRetry?.cancel()
        candidateRetry = nil
        anchorSession.resetRetryAttempts()
    }

    private func query(_ sender: Any) -> InputLocationQueryResult<NSRect> {
        guard let textClient = sender as? IMKTextInput else {
            return .unavailable
        }

        var rejectedPlaceholder = false
        let characterIndices = InputLocationQueryPolicy.characterIndices(
            markedRange: textClient.markedRange(),
            selectedRange: textClient.selectedRange()
        )
        var lastQueriedRect = NSRect.zero
        for characterIndex in characterIndices {
            var lineRect = NSRect.zero
            _ = textClient.attributes(
                forCharacterIndex: characterIndex,
                lineHeightRectangle: &lineRect
            )
            lastQueriedRect = lineRect
            let isValidRectangle = isValid(lineRect)
            let isPlaceholder = isValidRectangle
                && isScreenCornerPlaceholder(lineRect)
            if isPlaceholder {
                rejectedPlaceholder = true
                logger.notice(
                    "rejected top-left input placeholder index=\(characterIndex, privacy: .public) rect=\(String(describing: lineRect), privacy: .public)"
                )
            }
            if isValidRectangle, !isPlaceholder {
                logger.notice(
                    "accepted IMK input location index=\(characterIndex, privacy: .public) rect=\(String(describing: lineRect), privacy: .public)"
                )
                return .accepted(lineRect)
            }
        }
        if let nativeTextClient = sender as? NSTextInputClient {
            var actualRange = NSRange(location: NSNotFound, length: 0)
            let fallbackRange = textClient.markedRange().location != NSNotFound
                ? textClient.markedRange()
                : textClient.selectedRange()
            let firstRect = nativeTextClient.firstRect(
                forCharacterRange: fallbackRange,
                actualRange: &actualRange
            )
            let isValidRectangle = isValid(firstRect)
            let isPlaceholder = isValidRectangle
                && isScreenCornerPlaceholder(firstRect)
            if isPlaceholder {
                rejectedPlaceholder = true
                logger.notice(
                    "rejected top-left NSTextInputClient placeholder rect=\(String(describing: firstRect), privacy: .public)"
                )
            }
            if isValidRectangle, !isPlaceholder {
                logger.notice(
                    "used NSTextInputClient fallback input location range=\(String(describing: actualRange), privacy: .public) rect=\(String(describing: firstRect), privacy: .public)"
                )
                return .accepted(firstRect)
            }
        }
        logger.notice(
            "invalid current input location indices=\(String(describing: characterIndices), privacy: .public) rect=\(String(describing: lastQueriedRect), privacy: .public)"
        )
        return rejectedPlaceholder ? .rejectedPlaceholder : .unavailable
    }

    private func isValid(_ rect: NSRect) -> Bool {
        InputLocationQueryPolicy.isValidRectangle(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height
        )
    }

    private func isScreenCornerPlaceholder(_ rect: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            let matchesFullScreen = InputLocationQueryPolicy.isTopLeftScreenPlaceholder(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: rect.height,
                screenMinX: screen.frame.minX,
                screenMaxY: screen.frame.maxY
            )
            let matchesVisibleScreen = InputLocationQueryPolicy.isTopLeftScreenPlaceholder(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: rect.height,
                screenMinX: screen.visibleFrame.minX,
                screenMaxY: screen.visibleFrame.maxY
            )
            return matchesFullScreen || matchesVisibleScreen
        }
    }
}
