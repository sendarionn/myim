@preconcurrency import Carbon
import Foundation
import os

/// A key that operates a panel the input method shows near the caret
enum PanelKeyCommand: Equatable {
    case previous
    case next
    /// Tab and Shift+Tab, told apart from the arrows for panels where Tab
    /// also starts a conversion
    case tab
    case backTab
    case apply
    case cancel
    case deleteBackward
}

/// Takes the keys that operate a panel as hot keys while it is shown, so
/// applications such as Chrome and VS Code, which also act on keys the input
/// method handled when there is no marked text, do not move their cursor,
/// focus or text with them; nothing is registered while the panel is closed.
/// A hot key reaches only its handler, so each press is handled once
final class PanelKeyCapture {
    private typealias Key = (keyCode: Int, modifiers: Int, command: PanelKeyCommand)

    private static let navigationKeys: [Key] = [
        (kVK_LeftArrow, 0, .previous),
        (kVK_UpArrow, 0, .previous),
        (kVK_RightArrow, 0, .next),
        (kVK_DownArrow, 0, .next),
        (kVK_Tab, 0, .tab),
        (kVK_Tab, shiftKey, .backTab),
        (kVK_Return, 0, .apply),
        (kVK_ANSI_KeypadEnter, 0, .apply),
        (kVK_Escape, 0, .cancel)
    ]

    /// Key codes of every captured key, for events that still arrive
    static let capturedKeyCodes: Set<UInt16> = Set(
        (navigationKeys.map(\.keyCode) + [kVK_Delete]).map { UInt16($0) }
    )

    static let selectionBracket = PanelKeyCapture(
        category: "selection-bracket",
        signature: 0x4D_59_42_4B,
        keys: navigationKeys,
        handler: { InputController.handleSelectionBracketCommand($0) }
    )

    /// Backspace edits the search text, and must not delete the document's
    /// text while formats are listed either
    static let bookmark = PanelKeyCapture(
        category: "bookmark",
        signature: 0x4D_59_42_4D,
        keys: navigationKeys + [(kVK_Delete, 0, .deleteBackward)],
        handler: { InputController.handleBookmarkPanelCommand($0) }
    )

    private let logger: Logger
    private let signature: OSType
    private let keys: [Key]
    private let handler: (PanelKeyCommand) -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []

    var isCapturing: Bool { !hotKeys.isEmpty }

    private init(
        category: String,
        signature: OSType,
        keys: [Key],
        handler: @escaping (PanelKeyCommand) -> Void
    ) {
        logger = Logger(
            subsystem: "io.github.sendarionn.inputmethod.myime",
            category: category
        )
        self.signature = signature
        self.keys = keys
        self.handler = handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // Instances live for the whole process as static constants
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
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
                let capture = Unmanaged<PanelKeyCapture>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                guard status == noErr,
                      identifier.signature == capture.signature,
                      let command = capture.command(for: identifier.id) else {
                    return OSStatus(eventNotHandledErr)
                }
                DispatchQueue.main.async {
                    capture.handler(command)
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func command(for identifier: UInt32) -> PanelKeyCommand? {
        let index = Int(identifier) - 1
        return keys.indices.contains(index) ? keys[index].command : nil
    }

    /// Returns false, with nothing left registered, unless every key is
    /// taken, so a key the panel shows as working never reaches the
    /// application
    func begin() -> Bool {
        end()
        for (index, key) in keys.enumerated() {
            let id = UInt32(index + 1)
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(key.keyCode),
                UInt32(key.modifiers),
                EventHotKeyID(signature: signature, id: id),
                GetApplicationEventTarget(),
                0,
                &reference
            )
            guard status == noErr, let reference else {
                logger.error(
                    "hot key registration failed id=\(id, privacy: .public) status=\(status, privacy: .public)"
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
