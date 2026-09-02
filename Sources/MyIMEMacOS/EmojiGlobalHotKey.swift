@preconcurrency import Carbon
import Foundation
import os

enum EmojiDiagnostics {
    static let logger = Logger(
        subsystem: "io.github.sendarionn.inputmethod.myime",
        category: "emoji"
    )
}

final class EmojiGlobalHotKey {
    static let shared = EmojiGlobalHotKey()

    private static let signature: OSType = 0x4D_59_49_4D
    private static let identifier: UInt32 = 1
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
                      identifier.signature == EmojiGlobalHotKey.signature,
                      identifier.id == EmojiGlobalHotKey.identifier else {
                    return OSStatus(eventNotHandledErr)
                }
                EmojiDiagnostics.logger.notice("global hot key received")
                DispatchQueue.main.async {
                    InputController.handleGlobalEmojiShortcut()
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
        guard hotKey == nil,
              UserDefaults.standard.object(
                forKey: MyIMFeatureShortcut.emoji.defaultsKey
              ) == nil else {
            return
        }
        let identifier = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_E),
            UInt32(optionKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if status != noErr {
            EmojiDiagnostics.logger.error(
                "global hot key registration failed status=\(status, privacy: .public)"
            )
        } else {
            EmojiDiagnostics.logger.notice("global hot key registered")
        }
    }

    func deactivate() {
        guard let hotKey else { return }
        UnregisterEventHotKey(hotKey)
        self.hotKey = nil
        EmojiDiagnostics.logger.notice("global hot key unregistered")
    }

    deinit {
        deactivate()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
