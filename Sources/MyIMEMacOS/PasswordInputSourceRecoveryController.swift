@preconcurrency import AppKit
@preconcurrency import ApplicationServices
import Carbon
import MyIMECore
import os

final class PasswordInputSourceRecoveryController {
    enum Status: Equatable {
        case disabled
        case accessibilityPermissionRequired
        case monitoring

        var description: String {
            switch self {
            case .disabled:
                return "無効"
            case .accessibilityPermissionRequired:
                return "Accessibility権限が必要"
            case .monitoring:
                return "監視中"
            }
        }
    }

    static let shared = PasswordInputSourceRecoveryController()

    private static let logger = Logger(
        subsystem: "io.github.sendarionn.inputmethod.myime",
        category: "PasswordInputSourceRecovery"
    )

    private let settings = InputFeatureSettings()
    private var state = PasswordInputSourceRecoveryState(
        myIMInputSourceIdentifier: InputSourceRegistrationManager.myIMIdentifier,
        currentInputSourceIdentifier: nil,
        currentApplicationIdentifier: nil
    )
    private var inputSourceObserver: NSObjectProtocol?
    private var applicationObserver: NSObjectProtocol?
    private var started = false
    /// Every Accessibility call to other applications happens on its thread
    private lazy var focusMonitor = AccessibilityFocusMonitor {
        generation, kind in
        PasswordInputSourceRecoveryController.shared
            .focusDidChange(generation: generation, kind: kind)
    }
    /// Results of an older generation describe an earlier application or
    /// state and are ignored
    private var focusGeneration: UInt = 0
    private var observedProcessIdentifier: pid_t?
    private var pendingRecovery: PasswordInputSourceRecoveryRequest?
    private var loggedStatus: Status?

    private init() {}

    var status: Status {
        guard settings.isPasswordInputSourceRecoveryEnabled else {
            return .disabled
        }
        return AXIsProcessTrusted() ? .monitoring
            : .accessibilityPermissionRequired
    }

    func start() {
        guard !started else { return }
        started = true
        refreshConfiguration(promptForAuthorization: false)
    }

    func refreshConfiguration(promptForAuthorization: Bool = false) {
        guard settings.isPasswordInputSourceRecoveryEnabled else {
            stopMonitoring()
            logStatusIfChanged(.disabled)
            return
        }
        let trusted: Bool
        if promptForAuthorization {
            trusted = AXIsProcessTrustedWithOptions([
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:
                    true
            ] as CFDictionary)
        } else {
            trusted = AXIsProcessTrusted()
        }
        guard trusted else {
            stopMonitoring()
            logStatusIfChanged(.accessibilityPermissionRequired)
            return
        }
        installMonitoringIfNeeded()
        logStatusIfChanged(.monitoring)
    }

    func requestAccessibilityAuthorization() {
        refreshConfiguration(promptForAuthorization: true)
    }

    private func installMonitoringIfNeeded() {
        if inputSourceObserver == nil {
            inputSourceObserver = DistributedNotificationCenter.default()
                .addObserver(
                    forName: Notification.Name(
                        kTISNotifySelectedKeyboardInputSourceChanged as String
                    ),
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.inputSourceDidChange()
                }
        }
        if applicationObserver == nil {
            applicationObserver = NSWorkspace.shared.notificationCenter
                .addObserver(
                    forName: NSWorkspace.didActivateApplicationNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    self?.frontmostApplicationDidChange(notification)
                }
        }
        let application = NSWorkspace.shared.frontmostApplication
        state = PasswordInputSourceRecoveryState(
            myIMInputSourceIdentifier:
                InputSourceRegistrationManager.myIMIdentifier,
            currentInputSourceIdentifier:
                InputSourceRegistrationManager.selectedSourceIdentifier(),
            currentApplicationIdentifier: application?.bundleIdentifier
        )
        stopObservingFocus()
    }

    private func logStatusIfChanged(_ status: Status) {
        guard loggedStatus != status else { return }
        loggedStatus = status
        Self.logger.notice(
            "status changed value=\(status.description, privacy: .public)"
        )
    }

    private func stopMonitoring() {
        if let inputSourceObserver {
            DistributedNotificationCenter.default().removeObserver(
                inputSourceObserver
            )
            self.inputSourceObserver = nil
        }
        if let applicationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(
                applicationObserver
            )
            self.applicationObserver = nil
        }
        stopObservingFocus()
        state.reset()
    }

    private func frontmostApplicationDidChange(_ notification: Notification) {
        let application = notification.userInfo?[
            NSWorkspace.applicationUserInfoKey
        ] as? NSRunningApplication
            ?? NSWorkspace.shared.frontmostApplication
        state.applicationChanged(to: application?.bundleIdentifier)
        Self.logger.debug(
            "frontmost application changed identifier=\(application?.bundleIdentifier ?? "unavailable", privacy: .private)"
        )
        updateFocusObservation()
    }

    private func inputSourceDidChange() {
        guard let source = InputSourceRegistrationManager.currentSource else {
            Self.logger.debug("input source changed identifier=unavailable")
            state.reset()
            updateFocusObservation()
            return
        }
        Self.logger.debug(
            "input source changed identifier=\(source.identifier, privacy: .public) ascii=\(source.isASCIICapableKeyboardLayout, privacy: .public)"
        )
        state.inputSourceChanged(
            to: source.identifier,
            isTemporaryASCIIKeyboard: source.isASCIICapableKeyboardLayout,
            applicationIdentifier:
                NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            now: ProcessInfo.processInfo.systemUptime
        )
        updateFocusObservation()
    }

    /// Accessibility messages run on the main thread of the application they
    /// are sent to, so its focus is watched only while a temporary switch
    /// waits for it, not throughout ordinary typing
    private func updateFocusObservation() {
        guard state.isAwaitingFocus,
              let application = NSWorkspace.shared.frontmostApplication,
              application.bundleIdentifier
                != "io.github.sendarionn.inputmethod.myime" else {
            stopObservingFocus()
            return
        }
        guard observedProcessIdentifier != application.processIdentifier else {
            return
        }
        focusGeneration &+= 1
        pendingRecovery = nil
        observedProcessIdentifier = application.processIdentifier
        focusMonitor.observe(
            processIdentifier: application.processIdentifier,
            generation: focusGeneration
        )
    }

    private func stopObservingFocus() {
        pendingRecovery = nil
        guard observedProcessIdentifier != nil else { return }
        observedProcessIdentifier = nil
        focusGeneration &+= 1
        focusMonitor.stop(generation: focusGeneration)
    }

    private func focusDidChange(
        generation: UInt,
        kind: PasswordInputFocusKind
    ) {
        guard generation == focusGeneration else { return }
        Self.logger.debug(
            "focused element changed kind=\(String(describing: kind), privacy: .public)"
        )
        if let request = pendingRecovery {
            pendingRecovery = nil
            recoverMyIMIfStillValid(request, focus: kind)
            updateFocusObservation()
            return
        }
        let request = state.focusChanged(
            to: kind,
            applicationIdentifier:
                NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            now: ProcessInfo.processInfo.systemUptime
        )
        if let request {
            // The focus is read once more just before acting on it
            pendingRecovery = request
            focusMonitor.refresh(generation: generation)
            return
        }
        updateFocusObservation()
    }

    private func recoverMyIMIfStillValid(
        _ request: PasswordInputSourceRecoveryRequest,
        focus: PasswordInputFocusKind
    ) {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                == request.applicationIdentifier,
              let source = InputSourceRegistrationManager.currentSource,
              source.identifier
                == request.temporaryInputSourceIdentifier,
              source.isASCIICapableKeyboardLayout,
              focus == .ordinaryText else {
            Self.logger.notice("recovery cancelled during final validation")
            return
        }
        do {
            try InputSourceRegistrationManager.selectMyIM()
            guard InputSourceRegistrationManager.isSelected else {
                Self.logger.error("recovery selection was not applied")
                return
            }
            Self.logger.notice("recovered myim after secure field")
        } catch {
            Self.logger.error(
                "recovery failed error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
