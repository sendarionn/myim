import Foundation

public enum InputLocationQueryResult<Location: Equatable>: Equatable {
    case accepted(Location)
    case rejectedPlaceholder
    case unavailable

    public var location: Location? {
        guard case let .accepted(location) = self else { return nil }
        return location
    }
}

public enum CandidateAnchorResolution<Location: Equatable>: Equatable {
    case current(Location)
    case composition(Location)
    case previous(Location)
    case deferredAfterPlaceholder
    case missing

    public var location: Location? {
        switch self {
        case let .current(location),
             let .composition(location),
             let .previous(location):
            return location
        case .deferredAfterPlaceholder, .missing:
            return nil
        }
    }

    public var shouldRetry: Bool {
        self == .deferredAfterPlaceholder
    }
}

public struct InputLocationAnchorSession<Location: Equatable>: Equatable {
    public private(set) var compositionAnchor: Location?
    public private(set) var lastValidLocation: Location?
    public private(set) var retryAttempt = 0

    public init() {}

    public mutating func record(
        _ result: InputLocationQueryResult<Location>
    ) {
        if let location = result.location {
            lastValidLocation = location
        }
    }

    public mutating func captureCompositionAnchor(
        _ result: InputLocationQueryResult<Location>
    ) {
        record(result)
        compositionAnchor = result.location
    }

    public mutating func fallbackLocation(
        after result: InputLocationQueryResult<Location>
    ) -> Location? {
        record(result)
        return lastValidLocation
    }

    public mutating func candidateAnchor(
        after result: InputLocationQueryResult<Location>
    ) -> CandidateAnchorResolution<Location> {
        record(result)
        switch result {
        case let .accepted(location):
            compositionAnchor = location
            return .current(location)
        case .rejectedPlaceholder:
            return .deferredAfterPlaceholder
        case .unavailable:
            if let compositionAnchor {
                return .composition(compositionAnchor)
            }
            if let lastValidLocation {
                return .previous(lastValidLocation)
            }
            return .missing
        }
    }

    public mutating func clearCompositionAnchor() {
        compositionAnchor = nil
    }

    public mutating func forgetPreviousLocation() {
        lastValidLocation = nil
    }

    public var nextRetryDelay: TimeInterval {
        CandidateLocationRetryPolicy.delay(after: retryAttempt)
    }

    @discardableResult
    public mutating func beginRetryAttempt() -> Int {
        retryAttempt += 1
        return retryAttempt
    }

    public mutating func resetRetryAttempts() {
        retryAttempt = 0
    }
}

extension InputLocationAnchorSession: Sendable where Location: Sendable {}
extension InputLocationQueryResult: Sendable where Location: Sendable {}
extension CandidateAnchorResolution: Sendable where Location: Sendable {}
