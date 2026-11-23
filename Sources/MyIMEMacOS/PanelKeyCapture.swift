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
        CarbonHotKeys.route(signature: signature) { [weak self] id, isPressed in
            guard let self, let command = self.command(for: id) else {
                return false
            }
            if isPressed {
                DispatchQueue.main.async {
                    self.handler(command)
                }
            }
            return true
        }
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
            switch CarbonHotKeys.register(
                keyCode: UInt32(key.keyCode),
                modifiers: UInt32(key.modifiers),
                signature: signature,
                id: id
            ) {
            case let .success(reference):
                hotKeys.append(reference)
            case let .failure(error):
                logger.error(
                    "hot key registration failed id=\(id, privacy: .public) status=\(error.status, privacy: .public)"
                )
                end()
                return false
            }
        }
        return true
    }

    func end() {
        CarbonHotKeys.unregister(hotKeys)
        hotKeys = []
    }
}
