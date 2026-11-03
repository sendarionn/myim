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
    private var accessibilityObserver: AXObserver?
    private var accessibilityApplication: AXUIElement?
    private var started = false
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
        observeAccessibilityFocus(in: application)
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
        removeAccessibilityObserver()
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
        observeAccessibilityFocus(in: application)
    }

    private func inputSourceDidChange() {
        guard let source = InputSourceRegistrationManager.currentSource else {
            Self.logger.debug("input source changed identifier=unavailable")
            state.reset()
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
    }

    private func observeAccessibilityFocus(
        in application: NSRunningApplication?
    ) {
        removeAccessibilityObserver()
        guard let application,
              application.bundleIdentifier
                != "io.github.sendarionn.inputmethod.myime" else {
            state.reset()
            return
        }
        let applicationElement = AXUIElementCreateApplication(
            application.processIdentifier
        )
        var observer: AXObserver?
        let creation = AXObserverCreate(
            application.processIdentifier,
            Self.accessibilityCallback,
            &observer
        )
        guard creation == .success, let observer else {
            state.reset()
            return
        }
        let registration = AXObserverAddNotification(
            observer,
            applicationElement,
            kAXFocusedUIElementChangedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
        guard registration == .success else {
            state.reset()
            return
        }
        accessibilityObserver = observer
        accessibilityApplication = applicationElement
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
        focusedElementDidChange()
    }

    private func removeAccessibilityObserver() {
        if let accessibilityObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(accessibilityObserver),
                .commonModes
            )
        }
        accessibilityObserver = nil
        accessibilityApplication = nil
    }

    private func focusedElementDidChange() {
        let applicationIdentifier = NSWorkspace.shared.frontmostApplication?
            .bundleIdentifier
        let kind = focusedElement().map(Self.focusKind) ?? .unavailable
        Self.logger.debug(
            "focused element changed kind=\(String(describing: kind), privacy: .public)"
        )
        let request = state.focusChanged(
            to: kind,
            applicationIdentifier: applicationIdentifier,
            now: ProcessInfo.processInfo.systemUptime
        )
        guard let request else { return }
        recoverMyIMIfStillValid(request)
    }

    private func recoverMyIMIfStillValid(
        _ request: PasswordInputSourceRecoveryRequest
    ) {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                == request.applicationIdentifier,
              let source = InputSourceRegistrationManager.currentSource,
              source.identifier
                == request.temporaryInputSourceIdentifier,
              source.isASCIICapableKeyboardLayout,
              focusedElement().map(Self.focusKind) == .ordinaryText else {
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

    private func focusedElement() -> AXUIElement? {
        guard let accessibilityApplication else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            accessibilityApplication,
            kAXFocusedUIElementAttribute as CFString,
            &value
        ) == .success,
        let value,
        CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func focusKind(
        of element: AXUIElement
    ) -> PasswordInputFocusKind {
        let subrole = stringAttribute(
            kAXSubroleAttribute as CFString,
            from: element
        )
        let role = stringAttribute(
            kAXRoleAttribute as CFString,
            from: element
        )
        return PasswordInputFocusClassifier.classify(
            role: role,
            subrole: subrole
        )
    }

    private static func stringAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute,
            &value
        ) == .success else {
            return nil
        }
        return value as? String
    }

    private static let accessibilityCallback: AXObserverCallback = {
        _, _, notification, context in
        guard notification as String
                == kAXFocusedUIElementChangedNotification as String,
              let context else { return }
        let controller = Unmanaged<PasswordInputSourceRecoveryController>
            .fromOpaque(context)
            .takeUnretainedValue()
        DispatchQueue.main.async {
            controller.focusedElementDidChange()
        }
    }
}
