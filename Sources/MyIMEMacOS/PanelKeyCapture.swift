@preconcurrency import Carbon
import Foundation
import MyIMECore
import os

/// Takes the keys that operate the bracket panel as hot keys while it is
/// shown, so applications such as Chrome do not also move their cursor or
/// selection with them; nothing is registered while the panel is closed
final class SelectionBracketKeyCapture {
    static let shared = SelectionBracketKeyCapture()

    private static let logger = Logger(
        subsystem: "io.github.sendarionn.inputmethod.myime",
        category: "selection-bracket"
    )
    /// Differs from the emoji panel's, so each handles only its own keys
    private static let signature: OSType = 0x4D_59_42_4B

    private static let keys: [(id: UInt32, keyCode: Int, modifiers: Int,
                               command: SelectionBracketCommand)] = [
        (1, kVK_LeftArrow, 0, .previous),
        (2, kVK_UpArrow, 0, .previous),
        (3, kVK_RightArrow, 0, .next),
        (4, kVK_DownArrow, 0, .next),
        (5, kVK_Tab, 0, .next),
        (6, kVK_Tab, shiftKey, .previous),
        (7, kVK_Return, 0, .apply),
        (8, kVK_ANSI_KeypadEnter, 0, .apply),
        (9, kVK_Escape, 0, .cancel)
    ]

    private var eventHandler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []

    var isCapturing: Bool { !hotKeys.isEmpty }

    private init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
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
                      identifier.signature
                        == SelectionBracketKeyCapture.signature,
                      let command = SelectionBracketKeyCapture.keys.first(
                        where: { $0.id == identifier.id }
                      )?.command else {
                    return OSStatus(eventNotHandledErr)
                }
                DispatchQueue.main.async {
                    InputController.handleSelectionBracketCommand(command)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }

    /// Returns false, with nothing left registered, unless every key is
    /// taken, so a key the panel shows as working never reaches the
    /// application
    func begin() -> Bool {
        end()
        for key in Self.keys {
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(key.keyCode),
                UInt32(key.modifiers),
                EventHotKeyID(signature: Self.signature, id: key.id),
                GetApplicationEventTarget(),
                0,
                &reference
            )
            guard status == noErr, let reference else {
                Self.logger.error(
                    "hot key registration failed id=\(key.id, privacy: .public) status=\(status, privacy: .public)"
                )
                end()
                return false
            }
            hotKeys.append(reference)
        }
        return true
    }

    func end() {
        hotKeys.forEach { UnregisterEventHotKey($0) }
        hotKeys = []
    }
}
