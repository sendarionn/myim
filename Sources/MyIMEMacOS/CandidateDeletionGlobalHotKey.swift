@preconcurrency import Carbon
import Foundation
import os

final class CandidateDeletionGlobalHotKey {
    static let shared = CandidateDeletionGlobalHotKey()

    private static let signature: OSType = 0x4D_59_43_44
    private static let identifier: UInt32 = 1
    private static let logger = Logger(
        subsystem: "com.sendarionn.myim",
        category: "candidate-deletion"
    )

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    private init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                guard let event else {
                    return OSStatus(eventNotHandledErr)
                }
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
                        == CandidateDeletionGlobalHotKey.signature,
                      identifier.id
                        == CandidateDeletionGlobalHotKey.identifier else {
                    return OSStatus(eventNotHandledErr)
                }
                DispatchQueue.main.async {
                    InputController.handleGlobalCandidateDeletionShortcut()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }

    func activate() {
        guard hotKey == nil else { return }
        let identifier = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_X),
            UInt32(cmdKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard status == noErr else {
            hotKey = nil
            Self.logger.error(
                "candidate deletion hot key registration failed status=\(status, privacy: .public)"
            )
            return
        }
    }

    func deactivate() {
        guard let hotKey else { return }
        UnregisterEventHotKey(hotKey)
        self.hotKey = nil
    }

    deinit {
        deactivate()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
