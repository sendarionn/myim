@preconcurrency import Carbon
import Foundation

/// The hot keys the input method takes from applications: the emoji
/// shortcut, ⌘X for the selected candidate, and the keys of a shown panel.
/// One application event handler receives them all and hands each to the
/// owner of its signature; owners keep their own registration and timing,
/// such as the emoji panel's key repeat
enum CarbonHotKeys {
    /// Gets the hot key's identifier and whether it was pressed or
    /// released, on the main thread; returns false when it is not the
    /// owner's, so the event goes on
    typealias Handler = (_ id: UInt32, _ isPressed: Bool) -> Bool

    private static var handlers: [OSType: Handler] = [:]
    private static var eventHandler: EventHandlerRef?

    static func route(signature: OSType, to handler: @escaping Handler) {
        installIfNeeded()
        handlers[signature] = handler
    }

    /// One key as a hot key of the owner's signature; nil when another
    /// owner or application already holds it
    static func register(
        keyCode: UInt32,
        modifiers: UInt32,
        signature: OSType,
        id: UInt32
    ) -> Result<EventHotKeyRef, RegistrationError> {
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            EventHotKeyID(signature: signature, id: id),
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            return .failure(RegistrationError(status: status))
        }
        return .success(reference)
    }

    static func unregister(_ references: [EventHotKeyRef]) {
        references.forEach { UnregisterEventHotKey($0) }
    }

    struct RegistrationError: Error {
        let status: OSStatus
    }

    private static func installIfNeeded() {
        guard eventHandler == nil else { return }
        let eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]
        _ = eventTypes.withUnsafeBufferPointer { types in
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, _ in
                    guard let event else { return OSStatus(eventNotHandledErr) }
                    var identifier = EventHotKeyID()
                    let status = GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &identifier
                    )
                    guard status == noErr,
                          let handler = CarbonHotKeys.handlers[identifier.signature]
                    else {
                        return OSStatus(eventNotHandledErr)
                    }
                    let isPressed = GetEventKind(event)
                        == UInt32(kEventHotKeyPressed)
                    return handler(identifier.id, isPressed)
                        ? noErr
                        : OSStatus(eventNotHandledErr)
                },
                types.count,
                types.baseAddress,
                nil,
                &eventHandler
            )
        }
    }
}
