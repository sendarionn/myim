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

    private var hotKey: EventHotKeyRef?

    private init() {
        CarbonHotKeys.route(signature: Self.signature) { id, isPressed in
            guard id == CandidateDeletionGlobalHotKey.identifier else {
                return false
            }
            if isPressed {
                DispatchQueue.main.async {
                    InputController.handleGlobalCandidateDeletionShortcut()
                }
            }
            return true
        }
    }

    func activate() {
        guard hotKey == nil else { return }
        switch CarbonHotKeys.register(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(cmdKey),
            signature: Self.signature,
            id: Self.identifier
        ) {
        case let .success(reference):
            hotKey = reference
        case let .failure(error):
            Self.logger.error(
                "candidate deletion hot key registration failed status=\(error.status, privacy: .public)"
            )
        }
    }

    func deactivate() {
        guard let hotKey else { return }
        UnregisterEventHotKey(hotKey)
        self.hotKey = nil
    }

    deinit {
        deactivate()
    }
}
