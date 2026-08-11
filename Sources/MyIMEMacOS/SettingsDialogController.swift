@preconcurrency import AppKit
import MyIMECore

final class SettingsDialogController {
    struct ExternalCandidateSettings {
        let webSearchTemplate: String
        let azureKey: String
        let azureRegion: String
    }

    struct ExternalInformationSettings {
        let urlTemplate: String
        let displayDelay: TimeInterval
    }

    func dateTimeFormats(
        current: DateTimeCandidateGenerator.Formats
    ) -> DateTimeCandidateGenerator.Formats? {
        let dateField = NSTextField(
            string: current.date.joined(separator: ", ")
        )
        let timeField = NSTextField(
            string: current.time.joined(separator: ", ")
        )
        let dateTimeField = NSTextField(
            string: current.dateTime.joined(separator: ", ")
        )
        for field in [dateField, timeField, dateTimeField] {
            field.frame.size.width = 480
        }
        let stack = verticalStack(
            views: [
                NSTextField(labelWithString: "日付書式  カンマ区切り"),
                dateField,
                NSTextField(labelWithString: "時刻書式  カンマ区切り"),
                timeField,
                NSTextField(labelWithString: "日時書式  カンマ区切り"),
                dateTimeField,
                NSTextField(
                    labelWithString:
                        "使用可能: YYYY YY MM M DD D HH H mm m ss s"
                )
            ],
            size: NSSize(width: 480, height: 178)
        )
        let alert = makeAlert(
            title: "日時候補の書式",
            accessoryView: stack
        )
        guard runModal(alert, firstResponder: dateField)
            == .alertFirstButtonReturn else {
            return nil
        }
        return DateTimeCandidateGenerator.Formats(
            date: Self.parseFormats(dateField.stringValue),
            time: Self.parseFormats(timeField.stringValue),
            dateTime: Self.parseFormats(dateTimeField.stringValue)
        )
    }

    func externalCandidates(
        webSearchTemplate: String,
        azureKey: String,
        azureRegion: String
    ) -> ExternalCandidateSettings? {
        let searchTemplate = NSTextField(string: webSearchTemplate)
        searchTemplate.placeholderString = SearchURLTemplate.defaultValue
        let keyField = NSSecureTextField(string: azureKey)
        keyField.placeholderString = "Azure Translator APIキー"
        let regionField = NSTextField(string: azureRegion)
        regionField.placeholderString =
            "japaneast など  グローバルキーでは空欄"
        for field in [searchTemplate, keyField, regionField] {
            field.frame.size.width = 480
        }
        let stack = verticalStack(
            views: [
                NSTextField(labelWithString: "Web検索URL  %sを検索語へ置換"),
                searchTemplate,
                NSTextField(labelWithString: "Azure Translator APIキー"),
                keyField,
                NSTextField(labelWithString: "Azureリージョン"),
                regionField
            ],
            size: NSSize(width: 480, height: 142)
        )
        let alert = makeAlert(
            title: "外部候補とWeb検索",
            accessoryView: stack
        )
        guard runModal(alert, firstResponder: searchTemplate)
            == .alertFirstButtonReturn else {
            return nil
        }
        guard (try? SearchURLTemplate(searchTemplate.stringValue)) != nil else {
            NSSound.beep()
            return nil
        }
        return ExternalCandidateSettings(
            webSearchTemplate: searchTemplate.stringValue,
            azureKey: keyField.stringValue,
            azureRegion: regionField.stringValue
        )
    }

    func externalInformation(
        urlTemplate: String,
        displayDelay: TimeInterval
    ) -> ExternalInformationSettings? {
        let templateField = NSTextField(string: urlTemplate)
        templateField.placeholderString =
            "https://ja.wikipedia.org/w/index.php?search=%s"
        templateField.frame.size.width = 520
        let delayOptions: [(String, TimeInterval)] = [
            ("すぐ表示", 0),
            ("0.5秒後", 0.5),
            ("1秒後", 1),
            ("2秒後", 2),
            ("3秒後", 3),
            ("5秒後", 5)
        ]
        let delayPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        delayPopup.addItems(withTitles: delayOptions.map(\.0))
        delayPopup.selectItem(
            at: delayOptions.firstIndex { $0.1 == displayDelay } ?? 2
        )
        let stack = verticalStack(
            views: [
                NSTextField(labelWithString: "検索語を挿入する位置を%sで指定"),
                templateField,
                NSTextField(labelWithString: "表示タイミング"),
                delayPopup
            ],
            size: NSSize(width: 520, height: 96)
        )
        let alert = makeAlert(
            title: "外部情報パネルの検索先",
            accessoryView: stack
        )
        guard runModal(alert, firstResponder: templateField)
            == .alertFirstButtonReturn else {
            return nil
        }
        guard
            let template = try? SearchURLTemplate(templateField.stringValue),
            (try? template.url(for: "test")) != nil
        else {
            NSSound.beep()
            return nil
        }
        return ExternalInformationSettings(
            urlTemplate: templateField.stringValue,
            displayDelay: delayOptions[delayPopup.indexOfSelectedItem].1
        )
    }

    func runModal(
        _ alert: NSAlert,
        firstResponder: NSView
    ) -> NSApplication.ModalResponse {
        let previousPolicy = NSApp.activationPolicy()
        let changedPolicy = previousPolicy == .prohibited
            && NSApp.setActivationPolicy(.accessory)
        alert.window.initialFirstResponder = firstResponder
        NSRunningApplication.current.activate(
            options: [.activateIgnoringOtherApps, .activateAllWindows]
        )
        NSApp.activate(ignoringOtherApps: true)
        alert.window.makeKeyAndOrderFront(nil)
        alert.window.makeFirstResponder(firstResponder)
        let pasteMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { event in
            guard
                event.keyCode == 9,
                event.modifierFlags.contains(.command),
                let textField = firstResponder as? NSTextField,
                let value = NSPasteboard.general.string(forType: .string)
            else {
                return event
            }
            if let editor = textField.currentEditor() as? NSTextView {
                editor.insertText(value, replacementRange: editor.selectedRange())
            } else {
                textField.stringValue = value
            }
            return nil
        }
        DispatchQueue.main.async {
            alert.window.makeKey()
            alert.window.makeFirstResponder(firstResponder)
        }
        let response = alert.runModal()
        if let pasteMonitor {
            NSEvent.removeMonitor(pasteMonitor)
        }
        if changedPolicy {
            NSApp.setActivationPolicy(previousPolicy)
        }
        return response
    }

    private func makeAlert(title: String, accessoryView: NSView) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title
        alert.accessoryView = accessoryView
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "キャンセル")
        alert.window.level = .floating
        return alert
    }

    private func verticalStack(views: [NSView], size: NSSize) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.frame = NSRect(origin: .zero, size: size)
        return stack
    }

    private static func parseFormats(_ value: String) -> [String] {
        var seen = Set<String>()
        return value.split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
