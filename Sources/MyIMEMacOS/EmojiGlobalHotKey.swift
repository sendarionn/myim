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
    private var hotKey: EventHotKeyRef?
    private var panelHotKeys: [EventHotKeyRef] = []
    private var panelTabHotKeys: [EventHotKeyRef] = []
    private var repeatingCommand: UInt32?
    private var repeatTimer: DispatchSourceTimer?

    private init() {
        CarbonHotKeys.route(signature: Self.signature) { id, isPressed in
            if !isPressed {
                DispatchQueue.main.async {
                    EmojiGlobalHotKey.shared.stopRepeating(command: id)
                }
                return true
            }
            if id == EmojiGlobalHotKey.identifier {
                EmojiDiagnostics.logger.notice("global hot key received")
                DispatchQueue.main.async {
                    InputController.handleGlobalEmojiShortcut()
                }
            } else {
                DispatchQueue.main.async {
                    InputController.handleGlobalEmojiPanelCommand(id)
                    EmojiGlobalHotKey.shared.startRepeating(command: id)
                }
            }
            return true
        }
    }

    func activate() {
        guard hotKey == nil,
              UserDefaults.standard.object(
                forKey: MyIMFeatureShortcut.emoji.defaultsKey
              ) == nil else {
            return
        }
        switch CarbonHotKeys.register(
            keyCode: UInt32(kVK_ANSI_E),
            modifiers: UInt32(optionKey),
            signature: Self.signature,
            id: Self.identifier
        ) {
        case let .success(reference):
            hotKey = reference
            EmojiDiagnostics.logger.notice("global hot key registered")
        case let .failure(error):
            EmojiDiagnostics.logger.error(
                "global hot key registration failed status=\(error.status, privacy: .public)"
            )
        }
    }

    func deactivate() {
        endPanelCapture()
        guard let hotKey else { return }
        UnregisterEventHotKey(hotKey)
        self.hotKey = nil
        EmojiDiagnostics.logger.notice("global hot key unregistered")
    }

    func beginPanelCapture(capturesTab: Bool) {
        endPanelCapture()
        let shortcuts: [(UInt32, UInt32, UInt32)] = [
            (4, UInt32(kVK_LeftArrow), 0),
            (5, UInt32(kVK_RightArrow), 0),
            (6, UInt32(kVK_UpArrow), 0),
            (7, UInt32(kVK_DownArrow), 0),
            (8, UInt32(kVK_Return), 0),
            (9, UInt32(kVK_ANSI_KeypadEnter), 0),
            (10, UInt32(kVK_Escape), 0),
            // Chromium apps also perform Delete the input method handled
            // when nothing is composed, so it is taken before them
            (13, UInt32(kVK_Delete), 0)
        ]
        panelHotKeys = register(shortcuts, kind: "panel")
        EmojiDiagnostics.logger.notice(
            "panel hot keys registered count=\(self.panelHotKeys.count, privacy: .public)"
        )
        setPanelTabCaptureEnabled(capturesTab)
    }

    func setPanelTabCaptureEnabled(_ enabled: Bool) {
        if enabled, panelTabHotKeys.count == 2 { return }
        CarbonHotKeys.unregister(panelTabHotKeys)
        panelTabHotKeys = []
        guard enabled else {
            EmojiDiagnostics.logger.notice("panel Tab capture disabled")
            return
        }
        let shortcuts: [(UInt32, UInt32, UInt32)] = [
            (11, UInt32(kVK_Tab), 0),
            (12, UInt32(kVK_Tab), UInt32(shiftKey))
        ]
        panelTabHotKeys = register(shortcuts, kind: "panel Tab")
        EmojiDiagnostics.logger.notice(
            "panel Tab hot keys registered count=\(self.panelTabHotKeys.count, privacy: .public)"
        )
    }

    func endPanelCapture() {
        stopRepeating()
        CarbonHotKeys.unregister(panelHotKeys)
        panelHotKeys = []
        CarbonHotKeys.unregister(panelTabHotKeys)
        panelTabHotKeys = []
    }

    /// Registers what it can; a key another owner holds is logged and left
    private func register(
        _ shortcuts: [(UInt32, UInt32, UInt32)],
        kind: String
    ) -> [EventHotKeyRef] {
        shortcuts.compactMap { id, keyCode, modifiers in
            switch CarbonHotKeys.register(
                keyCode: keyCode,
                modifiers: modifiers,
                signature: Self.signature,
                id: id
            ) {
            case let .success(reference):
                return reference
            case let .failure(error):
                EmojiDiagnostics.logger.error(
                    "\(kind, privacy: .public) hot key registration failed id=\(id, privacy: .public) status=\(error.status, privacy: .public)"
                )
                return nil
            }
        }
    }

    private func startRepeating(command: UInt32) {
        guard (4...7).contains(command) || command == 13,
              repeatingCommand != command else {
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
            InputController.handleGlobalEmojiPanelCommand(
                command,
                isRepeat: true
            )
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
    }
}
