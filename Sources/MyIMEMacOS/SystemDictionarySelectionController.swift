@preconcurrency import AppKit

final class SystemDictionarySelectionController: NSObject,
    NSTableViewDataSource, NSTableViewDelegate {
    private struct Item {
        let name: String
        let description: String
        var isEnabled: Bool
    }

    private var items: [Item] = []
    private let tableView = NSTableView()
    private let moveUpButton = NSButton(title: "上へ", target: nil, action: nil)
    private let moveDownButton = NSButton(title: "下へ", target: nil, action: nil)

    func run(
        availableNames: [String],
        selectedNames: [String],
        descriptions: [String: String]
    ) -> [String]? {
        let availableSet = Set(availableNames)
        let orderedNames = selectedNames.filter(availableSet.contains)
            + availableNames.filter { !selectedNames.contains($0) }
        let selectedSet = Set(selectedNames)
        items = orderedNames.map {
            Item(
                name: $0,
                description: descriptions[$0] ?? "辞書",
                isEnabled: selectedSet.contains($0)
            )
        }

        let alert = NSAlert()
        alert.messageText = "表示するmacOS辞書"
        alert.informativeText = "上から順に辞書パネルへ表示します"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "キャンセル")
        alert.accessoryView = makeAccessoryView()
        tableView.reloadData()
        if !items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        updateMoveButtons()
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return items.compactMap { $0.isEnabled ? $0.name : nil }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard items.indices.contains(row) else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("DictionaryCheckbox")
        let checkbox: NSButton
        if let reused = tableView.makeView(
            withIdentifier: identifier,
            owner: self
        ) as? NSButton {
            checkbox = reused
        } else {
            checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggle(_:)))
            checkbox.identifier = identifier
            checkbox.lineBreakMode = .byTruncatingTail
        }
        let item = items[row]
        checkbox.title = "\(item.name)（\(item.description)）"
        checkbox.state = item.isEnabled ? .on : .off
        checkbox.tag = row
        return checkbox
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateMoveButtons()
    }

    @objc private func toggle(_ sender: NSButton) {
        guard items.indices.contains(sender.tag) else { return }
        items[sender.tag].isEnabled = sender.state == .on
        tableView.selectRowIndexes(
            IndexSet(integer: sender.tag),
            byExtendingSelection: false
        )
    }

    @objc private func moveUp(_ sender: Any?) {
        moveSelectedRow(by: -1)
    }

    @objc private func moveDown(_ sender: Any?) {
        moveSelectedRow(by: 1)
    }

    private func moveSelectedRow(by offset: Int) {
        let source = tableView.selectedRow
        let destination = source + offset
        guard items.indices.contains(source),
              items.indices.contains(destination) else { return }
        items.swapAt(source, destination)
        tableView.reloadData()
        tableView.selectRowIndexes(
            IndexSet(integer: destination),
            byExtendingSelection: false
        )
        tableView.scrollRowToVisible(destination)
        updateMoveButtons()
    }

    private func makeAccessoryView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 340))
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Dictionary"))
        column.width = dictionaryColumnWidth()
        column.resizingMask = []
        tableView.addTableColumn(column)
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.headerView = nil
        tableView.rowHeight = 28
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.dataSource = self
        tableView.delegate = self

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 470, height: 340))
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .bezelBorder
        container.addSubview(scrollView)

        moveUpButton.frame = NSRect(x: 478, y: 302, width: 62, height: 32)
        moveUpButton.target = self
        moveUpButton.action = #selector(moveUp(_:))
        container.addSubview(moveUpButton)

        moveDownButton.frame = NSRect(x: 478, y: 266, width: 62, height: 32)
        moveDownButton.target = self
        moveDownButton.action = #selector(moveDown(_:))
        container.addSubview(moveDownButton)
        return container
    }

    private func dictionaryColumnWidth() -> CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let widestTitle = items.map {
            "\($0.name)（\($0.description)）" as NSString
        }.map {
            $0.size(withAttributes: attributes).width
        }.max() ?? 0
        return max(462, ceil(widestTitle) + 42)
    }

    private func updateMoveButtons() {
        let row = tableView.selectedRow
        moveUpButton.isEnabled = row > 0
        moveDownButton.isEnabled = row >= 0 && row < items.count - 1
    }
}
