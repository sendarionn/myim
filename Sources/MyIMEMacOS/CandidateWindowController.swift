@preconcurrency import AppKit

final class CandidateWindowController: NSObject {
    private let panel: NSPanel
    private let tableView: NSTableView
    private var candidates: [String] = []

    override init() {
        tableView = NSTableView()
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        super.init()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("candidate"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 30
        tableView.intercellSpacing = .zero
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsEmptySelection = false

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        panel.contentView = scrollView
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.isOpaque = true
        panel.isReleasedWhenClosed = false
    }

    var frame: NSRect {
        panel.frame
    }

    func show(candidates: [String], selectedIndex: Int, near anchorFrame: NSRect) {
        self.candidates = candidates
        tableView.reloadData()

        let visibleRows = min(max(candidates.count, 1), 8)
        let height = CGFloat(visibleRows) * tableView.rowHeight
        panel.setContentSize(NSSize(width: 260, height: height))
        panel.setFrameTopLeftPoint(
            NSPoint(x: anchorFrame.minX, y: anchorFrame.maxY)
        )
        select(index: selectedIndex)
        panel.orderFrontRegardless()
    }

    func select(index: Int) {
        guard candidates.indices.contains(index) else {
            return
        }

        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    func hide() {
        panel.orderOut(nil)
    }
}

extension CandidateWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        candidates.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("candidateCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self)
            as? NSTableCellView
            ?? NSTableCellView()

        if cell.textField == nil {
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(textField)
            cell.textField = textField
            cell.identifier = identifier
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        cell.textField?.stringValue = candidates[row]
        return cell
    }
}
