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
    private var panelHotKeys: [EventHotKeyRef] = []

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
                      identifier.signature == EmojiGlobalHotKey.signature else {
                    return OSStatus(eventNotHandledErr)
                }
                if identifier.id == EmojiGlobalHotKey.identifier {
                    EmojiDiagnostics.logger.notice("global hot key received")
                    DispatchQueue.main.async {
                        InputController.handleGlobalEmojiShortcut()
                    }
                } else {
                    let command = identifier.id
                    InputController.handleGlobalEmojiPanelCommand(command)
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
        endPanelCapture()
        guard let hotKey else { return }
        UnregisterEventHotKey(hotKey)
        self.hotKey = nil
        EmojiDiagnostics.logger.notice("global hot key unregistered")
    }

    func beginPanelCapture() {
        endPanelCapture()
        let shortcuts: [(UInt32, UInt32, UInt32)] = [
            (4, UInt32(kVK_LeftArrow), 0),
            (5, UInt32(kVK_RightArrow), 0),
            (6, UInt32(kVK_UpArrow), 0),
            (7, UInt32(kVK_DownArrow), 0),
            (8, UInt32(kVK_Return), 0),
            (9, UInt32(kVK_ANSI_KeypadEnter), 0),
            (10, UInt32(kVK_Escape), 0)
        ]
        for (id, keyCode, modifiers) in shortcuts {
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(
                keyCode,
                modifiers,
                EventHotKeyID(signature: Self.signature, id: id),
                GetApplicationEventTarget(),
                0,
                &reference
            )
            if status == noErr, let reference {
                panelHotKeys.append(reference)
            } else {
                EmojiDiagnostics.logger.error(
                    "panel hot key registration failed id=\(id, privacy: .public) status=\(status, privacy: .public)"
                )
            }
        }
        EmojiDiagnostics.logger.notice(
            "panel hot keys registered count=\(self.panelHotKeys.count, privacy: .public)"
        )
    }

    func endPanelCapture() {
        panelHotKeys.forEach { UnregisterEventHotKey($0) }
        panelHotKeys = []
    }

    deinit {
        deactivate()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
