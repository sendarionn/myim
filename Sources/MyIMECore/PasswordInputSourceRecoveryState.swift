import Foundation

public enum PasswordInputFocusKind: Equatable, Sendable {
    case secureText
    case ordinaryText
    case other
    case unavailable
}

public enum PasswordInputFocusClassifier {
    public static func classify(
        role: String?,
        subrole: String?
    ) -> PasswordInputFocusKind {
        if subrole == "AXSecureTextField" {
            return .secureText
        }
        if let role,
           ["AXTextField", "AXTextArea", "AXComboBox"].contains(role) {
            return .ordinaryText
        }
        return role == nil && subrole == nil ? .unavailable : .other
    }
}

public struct PasswordInputSourceRecoveryRequest: Equatable, Sendable {
    public let applicationIdentifier: String
    public let temporaryInputSourceIdentifier: String

    public init(
        applicationIdentifier: String,
        temporaryInputSourceIdentifier: String
    ) {
        self.applicationIdentifier = applicationIdentifier
        self.temporaryInputSourceIdentifier = temporaryInputSourceIdentifier
    }
}

/// Correlates a secure-field focus change with the system's temporary switch
/// from myim to an ASCII keyboard layout
public struct PasswordInputSourceRecoveryState: Equatable, Sendable {
    private struct Observation: Equatable, Sendable {
        let applicationIdentifier: String
        let timestamp: TimeInterval
    }

    private struct TemporarySwitch: Equatable, Sendable {
        let applicationIdentifier: String
        let inputSourceIdentifier: String
        let timestamp: TimeInterval
    }

    public static let defaultCorrelationInterval: TimeInterval = 1

    public let myIMInputSourceIdentifier: String
    public let correlationInterval: TimeInterval
    public private(set) var currentInputSourceIdentifier: String?
    public private(set) var currentApplicationIdentifier: String?

    private var recentSecureFocus: Observation?
    private var pendingSwitch: TemporarySwitch?
    private var confirmedSwitch: TemporarySwitch?

    public init(
        myIMInputSourceIdentifier: String,
        currentInputSourceIdentifier: String?,
        currentApplicationIdentifier: String?,
        correlationInterval: TimeInterval = Self.defaultCorrelationInterval
    ) {
        self.myIMInputSourceIdentifier = myIMInputSourceIdentifier
        self.currentInputSourceIdentifier = currentInputSourceIdentifier
        self.currentApplicationIdentifier = currentApplicationIdentifier
        self.correlationInterval = correlationInterval
    }

    public mutating func applicationChanged(to identifier: String?) {
        guard currentApplicationIdentifier != identifier else { return }
        currentApplicationIdentifier = identifier
        clearTransientState()
    }

    public mutating func inputSourceChanged(
        to identifier: String?,
        isTemporaryASCIIKeyboard: Bool,
        applicationIdentifier: String?,
        now: TimeInterval
    ) {
        expireUnconfirmedObservations(now: now)
        let previousIdentifier = currentInputSourceIdentifier
        currentInputSourceIdentifier = identifier

        guard let identifier,
              let applicationIdentifier,
              applicationIdentifier == currentApplicationIdentifier else {
            clearTransientState()
            return
        }
        if identifier == myIMInputSourceIdentifier {
            clearTransientState()
            return
        }
        if let confirmedSwitch {
            if identifier == confirmedSwitch.inputSourceIdentifier {
                return
            }
            clearTransientState()
            return
        }
        if let pendingSwitch {
            if identifier == pendingSwitch.inputSourceIdentifier {
                return
            }
            clearTransientState()
            return
        }
        guard previousIdentifier == myIMInputSourceIdentifier,
              isTemporaryASCIIKeyboard else {
            clearTransientState()
            return
        }

        let transition = TemporarySwitch(
            applicationIdentifier: applicationIdentifier,
            inputSourceIdentifier: identifier,
            timestamp: now
        )
        pendingSwitch = transition
        if matchesRecentSecureFocus(transition, now: now) {
            confirmedSwitch = transition
            pendingSwitch = nil
        }
    }

    public mutating func focusChanged(
        to kind: PasswordInputFocusKind,
        applicationIdentifier: String?,
        now: TimeInterval
    ) -> PasswordInputSourceRecoveryRequest? {
        expireUnconfirmedObservations(now: now)
        guard let applicationIdentifier,
              applicationIdentifier == currentApplicationIdentifier else {
            clearTransientState()
            return nil
        }

        switch kind {
        case .secureText:
            let observation = Observation(
                applicationIdentifier: applicationIdentifier,
                timestamp: now
            )
            recentSecureFocus = observation
            if let pendingSwitch,
               abs(now - pendingSwitch.timestamp) <= correlationInterval,
               pendingSwitch.applicationIdentifier == applicationIdentifier {
                confirmedSwitch = pendingSwitch
                self.pendingSwitch = nil
            }
            return nil

        case .ordinaryText:
            guard let confirmedSwitch,
                  confirmedSwitch.applicationIdentifier
                    == applicationIdentifier,
                  currentInputSourceIdentifier
                    == confirmedSwitch.inputSourceIdentifier else {
                clearTransientState()
                return nil
            }
            let request = PasswordInputSourceRecoveryRequest(
                applicationIdentifier: applicationIdentifier,
                temporaryInputSourceIdentifier:
                    confirmedSwitch.inputSourceIdentifier
            )
            clearTransientState()
            return request

        case .other, .unavailable:
            clearTransientState()
            return nil
        }
    }

    public mutating func reset() {
        clearTransientState()
    }

    private func matchesRecentSecureFocus(
        _ transition: TemporarySwitch,
        now: TimeInterval
    ) -> Bool {
        guard let recentSecureFocus else { return false }
        return recentSecureFocus.applicationIdentifier
                == transition.applicationIdentifier
            && abs(now - recentSecureFocus.timestamp) <= correlationInterval
    }

    private mutating func expireUnconfirmedObservations(now: TimeInterval) {
        if let recentSecureFocus,
           now - recentSecureFocus.timestamp > correlationInterval {
            self.recentSecureFocus = nil
        }
        if let pendingSwitch,
           now - pendingSwitch.timestamp > correlationInterval {
            self.pendingSwitch = nil
        }
    }

    private mutating func clearTransientState() {
        recentSecureFocus = nil
        pendingSwitch = nil
        confirmedSwitch = nil
    }
}
