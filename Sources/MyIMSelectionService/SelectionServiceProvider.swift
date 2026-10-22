import AppKit
import MyIMECore
import os

final class SelectionServiceProvider: NSObject {
    /// The owner of the frontmost normal window other than this process
    static func frontmostWindowOwner(excluding ownPID: pid_t) -> pid_t? {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }
        for window in windows {
            guard (window[kCGWindowLayer as String] as? Int) == 0,
                  let owner = window[kCGWindowOwnerPID as String] as? pid_t,
                  owner != ownPID else {
                continue
            }
            return owner
        }
        return nil
    }

    private static let legacyStringType = NSPasteboard.PasteboardType(
        "NSStringPboardType"
    )
    private static let logger = Logger(
        subsystem: "io.github.sendarionn.inputmethod.myime",
        category: "selection-service"
    )
    private let registrationWindow = SelectionRegistrationWindowController()

    @objc
    func captureSelection(
        _ pasteboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let receivedText = pasteboard.string(forType: .string)
            ?? pasteboard.string(forType: Self.legacyStringType)
        guard let text = SelectionServiceText.received(receivedText) else {
            Self.logger.error(
                "capture failed stage=service-pasteboard reason=no-text"
            )
            error.pointee = "選択文字列を取得できません" as NSString
            return
        }

        // Recorded before the registration window comes forward. The
        // service is already frontmost when called, while the menu bar and
        // the frontmost window still belong to the source application
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let sources: [pid_t?] = [
            NSWorkspace.shared.frontmostApplication?.processIdentifier,
            NSWorkspace.shared.menuBarOwningApplication?.processIdentifier,
            Self.frontmostWindowOwner(excluding: ownPID)
        ]
        let source = sources.lazy.compactMap { $0 }
            .first { $0 > 0 && $0 != ownPID }
        Self.logger.notice(
            "capture succeeded source=macos-service length=\(text.count, privacy: .public) sourceRecorded=\(source != nil, privacy: .public)"
        )
        DispatchQueue.main.async { [registrationWindow] in
            registrationWindow.show(
                prefilledInsertedText: text,
                sourceProcessIdentifiers: sources
            )
        }
    }
}
