import AppKit
@preconcurrency import ApplicationServices
@preconcurrency import Carbon
import MyIMECore
import os

private enum SelectionBridgeDiagnostics {
    static let logger = Logger(
        subsystem: "io.github.sendarionn.inputmethod.myime",
        category: "selection-bridge"
    )
}

@MainActor
final class SelectionBridge {
    static let shared = SelectionBridge()

    private let captureService = SelectionCaptureService()
    private var isCapturing = false

    private init() {}

    func captureSelection() {
        guard !isCapturing else {
            SelectionBridgeDiagnostics.logger.notice(
                "capture ignored because another capture is running"
            )
            return
        }
        let target = NSWorkspace.shared.frontmostApplication
        guard let target, target.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            SelectionBridgeDiagnostics.logger.error(
                "capture failed stage=target reason=no-frontmost-application"
            )
            NSSound.beep()
            return
        }
        isCapturing = true
        SelectionBridgeDiagnostics.logger.notice(
            "capture started target=\(target.bundleIdentifier ?? "unknown", privacy: .public)"
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await captureService.capture(
                pasteboard: GeneralSelectionPasteboard(),
                copySender: FrontmostApplicationCopySender(
                    processIdentifier: target.processIdentifier
                )
            )
            isCapturing = false
            switch result {
            case let .success(text):
                SelectionBridgeDiagnostics.logger.notice(
                    "capture succeeded target=\(target.bundleIdentifier ?? "unknown", privacy: .public) length=\(text.count, privacy: .public)"
                )
                NSSound(named: "Tink")?.play()
            case let .failure(failure):
                SelectionBridgeDiagnostics.logger.error(
                    "capture failed target=\(target.bundleIdentifier ?? "unknown", privacy: .public) stage=\(String(describing: failure), privacy: .public)"
                )
                NSSound.beep()
            }
        }
    }
}

@MainActor
private final class GeneralSelectionPasteboard: SelectionPasteboardClient {
    private static let sentinelType = NSPasteboard.PasteboardType(
        "io.github.sendarionn.inputmethod.myime.selection-sentinel"
    )
    private let pasteboard = NSPasteboard.general

    var changeCount: Int { pasteboard.changeCount }

    func snapshot() throws -> SelectionPasteboardSnapshot {
        let items = try (pasteboard.pasteboardItems ?? []).map { item in
            try Dictionary(uniqueKeysWithValues: item.types.map { type in
                guard let data = item.data(forType: type) else {
                    throw SelectionPasteboardError.unavailableRepresentation
                }
                return (type.rawValue, data)
            })
        }
        return SelectionPasteboardSnapshot(items: items)
    }

    func prepareForCopy() throws -> Int {
        pasteboard.clearContents()
        guard pasteboard.setString(
            UUID().uuidString,
            forType: Self.sentinelType
        ) else {
            throw SelectionPasteboardError.writeFailed
        }
        return pasteboard.changeCount
    }

    func copiedString() -> String? {
        pasteboard.string(forType: .string)
    }

    func restore(_ snapshot: SelectionPasteboardSnapshot) throws {
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return }
        let items: [NSPasteboardItem?] = snapshot.items.map { representations in
            let item = NSPasteboardItem()
            for (rawType, data) in representations {
                guard item.setData(
                    data,
                    forType: NSPasteboard.PasteboardType(rawType)
                ) else {
                    return nil
                }
            }
            return item
        }
        guard !items.contains(where: { $0 == nil }),
              pasteboard.writeObjects(items.compactMap { $0 }) else {
            throw SelectionPasteboardError.writeFailed
        }
    }
}

private enum SelectionPasteboardError: Error {
    case unavailableRepresentation
    case writeFailed
}

private struct FrontmostApplicationCopySender: SelectionCopySender {
    let processIdentifier: pid_t

    func sendCopy() -> Bool {
        guard isAccessibilityTrusted() else { return false }
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: true
              ),
              let up = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: false
              ) else {
            return false
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(processIdentifier)
        up.postToPid(processIdentifier)
        return true
    }

    private func isAccessibilityTrusted() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

final class SelectionBridgeGlobalHotKey {
    static let shared = SelectionBridgeGlobalHotKey()

    private static let signature: OSType = 0x4D_59_53_42
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
                      identifier.signature
                        == SelectionBridgeGlobalHotKey.signature,
                      identifier.id
                        == SelectionBridgeGlobalHotKey.identifier else {
                    return OSStatus(eventNotHandledErr)
                }
                DispatchQueue.main.async {
                    SelectionBridge.shared.captureSelection()
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
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(controlKey | optionKey),
            EventHotKeyID(signature: Self.signature, id: Self.identifier),
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if status == noErr {
            SelectionBridgeDiagnostics.logger.notice(
                "global hot key registered shortcut=control-option-d"
            )
        } else {
            SelectionBridgeDiagnostics.logger.error(
                "global hot key registration failed status=\(status, privacy: .public)"
            )
        }
    }
}
