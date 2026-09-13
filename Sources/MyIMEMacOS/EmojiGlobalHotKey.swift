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
    private var repeatingCommand: UInt32?
    private var repeatTimer: DispatchSourceTimer?

    private init() {
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
                      identifier.signature == EmojiGlobalHotKey.signature else {
                    return OSStatus(eventNotHandledErr)
                }
                let isPressed = GetEventKind(event)
                    == UInt32(kEventHotKeyPressed)
                if !isPressed {
                    DispatchQueue.main.async {
                        EmojiGlobalHotKey.shared.stopRepeating(
                            command: identifier.id
                        )
                    }
                    return noErr
                }
                if identifier.id == EmojiGlobalHotKey.identifier {
                    EmojiDiagnostics.logger.notice("global hot key received")
                    DispatchQueue.main.async {
                        InputController.handleGlobalEmojiShortcut()
                    }
                } else {
                    let command = identifier.id
                    DispatchQueue.main.async {
                        InputController.handleGlobalEmojiPanelCommand(command)
                        EmojiGlobalHotKey.shared.startRepeating(
                            command: command
                        )
                    }
                }
                return noErr
                },
                types.count,
                types.baseAddress,
                nil,
                &eventHandler
            )
        }
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
        stopRepeating()
        panelHotKeys.forEach { UnregisterEventHotKey($0) }
        panelHotKeys = []
    }

    private func startRepeating(command: UInt32) {
        guard (4...7).contains(command), repeatingCommand != command else {
            return
        }
        stopRepeating()
        repeatingCommand = command
        let timer = DispatchSource.makeTimerSource(queue: .main)
        let initialDelay = repeatMilliseconds(
            setting: "InitialKeyRepeat",
            fallback: 30
        )
        let interval = repeatMilliseconds(
            setting: "KeyRepeat",
            fallback: 5
        )
        timer.schedule(
            deadline: .now() + .milliseconds(initialDelay),
            repeating: .milliseconds(interval),
            leeway: .milliseconds(5)
        )
        timer.setEventHandler { [weak self] in
            guard let self,
                  self.repeatingCommand == command else { return }
            InputController.handleGlobalEmojiPanelCommand(command)
        }
        repeatTimer = timer
        timer.resume()
    }

    private func repeatMilliseconds(
        setting: String,
        fallback: Int
    ) -> Int {
        let ticks = (UserDefaults.standard.object(forKey: setting) as? NSNumber)?
            .intValue ?? fallback
        return max(ticks, 1) * 15
    }

    private func stopRepeating(command: UInt32? = nil) {
        if let command, command != repeatingCommand { return }
        repeatTimer?.cancel()
        repeatTimer = nil
        repeatingCommand = nil
    }

    deinit {
        deactivate()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
