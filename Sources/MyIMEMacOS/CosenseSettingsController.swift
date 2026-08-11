@preconcurrency import AppKit
import MyIMECore

final class CosenseSettingsController: NSObject {
    enum CredentialUpdate {
        case cancelled
        case updated(CosenseCredential?)
    }

    private let credentialStore = CosenseCredentialStore()
    private let dialogController = SettingsDialogController()
    private weak var tokenInput: NSSecureTextField?

    func credential(for project: String) -> CosenseCredential? {
        credentialStore.load(for: project)
    }

    func chooseProject(
        currentURLDescription: String
    ) -> CosenseProjectConfiguration? {
        let input = NSTextField(string: currentURLDescription)
        input.placeholderString = "https://scrapbox.io/project-name"
        input.frame = NSRect(x: 0, y: 0, width: 420, height: 24)
        let alert = NSAlert()
        alert.messageText = "Cosense拡張辞書"
        alert.informativeText =
            "dictionaryページを持つプロジェクトURLを入力"
        alert.accessoryView = input
        alert.addButton(withTitle: "設定")
        alert.addButton(withTitle: "キャンセル")
        alert.window.level = .floating
        guard dialogController.runModal(alert, firstResponder: input)
            == .alertFirstButtonReturn else {
            return nil
        }
        guard
            let url = URL(string: input.stringValue),
            let configuration = CosenseProjectConfiguration(projectURL: url)
        else {
            showInvalidProjectURLAlert()
            return nil
        }
        return configuration
    }

    func updateCredential(
        current: CosenseCredential?,
        project: String
    ) -> CredentialUpdate {
        let kindPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        kindPopup.addItems(
            withTitles: ["Personal Access Token", "Service Account"]
        )
        if current?.kind == .serviceAccount {
            kindPopup.selectItem(at: 1)
        }
        let tokenInput = NSSecureTextField(frame: .zero)
        tokenInput.placeholderString = "トークンまたはアクセスキー"
        tokenInput.frame.size.width = 420
        self.tokenInput = tokenInput
        let pasteButton = NSButton(
            title: "クリップボードから貼り付け",
            target: self,
            action: #selector(pasteCredential(_:))
        )
        let stack = NSStackView(views: [kindPopup, tokenInput, pasteButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 420, height: 92)
        let alert = NSAlert()
        alert.messageText = "Cosense認証"
        alert.informativeText =
            "Service Accountは現在のプロジェクトだけに使用"
        alert.accessoryView = stack
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")
        alert.window.level = .floating
        let response = dialogController.runModal(
            alert,
            firstResponder: tokenInput
        )
        let kind: CosenseCredential.Kind =
            kindPopup.indexOfSelectedItem == 1
                ? .serviceAccount
                : .personalAccessToken
        do {
            if response == .alertFirstButtonReturn {
                guard let credential = CosenseCredential(
                    kind: kind,
                    value: tokenInput.stringValue
                ) else {
                    NSSound.beep()
                    return .cancelled
                }
                try credentialStore.save(credential, project: project)
            } else if response == .alertSecondButtonReturn {
                try credentialStore.delete(kind: kind, project: project)
            } else {
                return .cancelled
            }
            return .updated(credentialStore.load(for: project))
        } catch {
            NSLog(
                "Cosense認証情報の保存に失敗: %@",
                error.localizedDescription
            )
            NSSound.beep()
            return .cancelled
        }
    }

    @objc
    private func pasteCredential(_ sender: Any?) {
        guard
            let value = NSPasteboard.general.string(forType: .string),
            !value.isEmpty
        else {
            NSSound.beep()
            return
        }
        tokenInput?.stringValue = value
        tokenInput?.window?.makeFirstResponder(tokenInput)
    }

    private func showInvalidProjectURLAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "URLを設定できません"
        alert.informativeText =
            "https://scrapbox.io/project-name の形式で入力"
        alert.addButton(withTitle: "OK")
        alert.window.level = .floating
        alert.runModal()
    }
}
