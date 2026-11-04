@preconcurrency import ApplicationServices
import Foundation
import MyIMECore
import os

/// Owns every Accessibility call to other applications on a thread of its
/// own. An application that does not answer, or is itself waiting for the
/// input method, can only hold up this thread and only until the messaging
/// timeout, never the main thread that handles typing
final class AccessibilityFocusMonitor: @unchecked Sendable {
    /// Seconds an application has to answer one Accessibility message
    static let messagingTimeout: Float = 0.25
    private static let slowQueryMilliseconds = 100

    private static let logger = Logger(
        subsystem: "io.github.sendarionn.inputmethod.myime",
        category: "PasswordInputSourceRecovery"
    )

    /// Called on the main thread with the generation of the request
    private let focusChanged: @Sendable (UInt, PasswordInputFocusKind) -> Void
    private var workerRunLoop: CFRunLoop?

    // Touched only on the worker thread
    private var observer: AXObserver?
    private var application: AXUIElement?
    private var generation: UInt = 0
    private var refreshScheduled = false

    init(
        focusChanged: @escaping @Sendable (UInt, PasswordInputFocusKind) -> Void
    ) {
        self.focusChanged = focusChanged
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            self?.workerRunLoop = CFRunLoopGetCurrent()
            // Applies to every element this process creates
            AXUIElementSetMessagingTimeout(
                AXUIElementCreateSystemWide(),
                Self.messagingTimeout
            )
            // Keeps the run loop waiting while nothing is observed
            var context = CFRunLoopSourceContext()
            let source = CFRunLoopSourceCreate(nil, 0, &context)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            ready.signal()
            CFRunLoopRun()
        }
        thread.name = "myim.accessibility-focus"
        thread.qualityOfService = .utility
        thread.start()
        ready.wait()
    }

    /// Watches focus changes in the application and reads its focus once
    func observe(processIdentifier: pid_t, generation: UInt) {
        perform { [self] in
            removeObserver()
            self.generation = generation
            let element = AXUIElementCreateApplication(processIdentifier)
            var created: AXObserver?
            guard AXObserverCreate(
                processIdentifier,
                Self.callback,
                &created
            ) == .success, let created,
            AXObserverAddNotification(
                created,
                element,
                kAXFocusedUIElementChangedNotification as CFString,
                Unmanaged.passUnretained(self).toOpaque()
            ) == .success else {
                report(.unavailable)
                return
            }
            observer = created
            application = element
            CFRunLoopAddSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(created),
                .commonModes
            )
            scheduleRefresh()
        }
    }

    /// Reads the focus again for a decision about to be acted on
    func refresh(generation: UInt) {
        perform { [self] in
            guard generation == self.generation else { return }
            scheduleRefresh()
        }
    }

    func stop(generation: UInt) {
        perform { [self] in
            self.generation = generation
            removeObserver()
        }
    }

    private func perform(_ block: @escaping () -> Void) {
        guard let workerRunLoop else { return }
        CFRunLoopPerformBlock(
            workerRunLoop,
            CFRunLoopMode.commonModes.rawValue,
            block
        )
        CFRunLoopWakeUp(workerRunLoop)
    }

    private func removeObserver() {
        if let observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
        }
        observer = nil
        application = nil
    }

    /// Focus changes in quick succession are read once
    private func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        perform { [self] in
            refreshScheduled = false
            guard let application else { return }
            let start = DispatchTime.now().uptimeNanoseconds
            let kind = Self.focusKind(in: application)
            let milliseconds = Int(
                (DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            )
            if milliseconds >= Self.slowQueryMilliseconds {
                Self.logger.notice(
                    "slow accessibility query ms=\(milliseconds, privacy: .public) kind=\(String(describing: kind), privacy: .public)"
                )
            }
            report(kind)
        }
    }

    private func report(_ kind: PasswordInputFocusKind) {
        let generation = generation
        let focusChanged = focusChanged
        DispatchQueue.main.async {
            focusChanged(generation, kind)
        }
    }

    private static func focusKind(
        in application: AXUIElement
    ) -> PasswordInputFocusKind {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXFocusedUIElementAttribute as CFString,
            &value
        ) == .success,
        let value,
        CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return .unavailable
        }
        let element = value as! AXUIElement
        return PasswordInputFocusClassifier.classify(
            role: stringAttribute(kAXRoleAttribute as CFString, from: element),
            subrole: stringAttribute(
                kAXSubroleAttribute as CFString,
                from: element
            )
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

    private static let callback: AXObserverCallback = {
        _, _, notification, context in
        guard notification as String
                == kAXFocusedUIElementChangedNotification as String,
              let context else { return }
        Unmanaged<AccessibilityFocusMonitor>
            .fromOpaque(context)
            .takeUnretainedValue()
            .scheduleRefresh()
    }
}
