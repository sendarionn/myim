@preconcurrency import AppKit

private final class CalendarPanel: NSPanel {
    var cancelAction: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        cancelAction?()
    }
}

private final class CalendarDatePicker: NSDatePicker {
    var confirmAction: (() -> Void)?
    var cancelAction: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            confirmAction?()
        case 53:
            cancelAction?()
        default:
            super.keyDown(with: event)
        }
    }
}

private final class CalendarFormatKeyPanel: NSPanel {
    var candidateCount = 0
    var selectedIndex: Int?
    var selectionChanged: ((Int?) -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 48, 124, 125:
            guard candidateCount > 0 else { return }
            let direction = event.keyCode == 48
                && event.modifierFlags.contains(.shift) ? -1 : 1
            moveSelection(by: direction)
        case 123, 126:
            moveSelection(by: -1)
        case 36, 76:
            guard selectedIndex != nil else { return }
            NSApp.stopModal(withCode: .OK)
        case 53:
            NSApp.stopModal(withCode: .cancel)
        default:
            break
        }
    }

    private func moveSelection(by offset: Int) {
        guard candidateCount > 0 else { return }
        let current = selectedIndex ?? (offset > 0 ? -1 : 0)
        selectedIndex = (current + offset + candidateCount) % candidateCount
        selectionChanged?(selectedIndex)
    }
}

final class CalendarWindowController: NSObject {
    private static let calendarScale: CGFloat = 1.2

    private let panel: CalendarPanel
    private let formatKeyPanel: CalendarFormatKeyPanel
    private let datePicker: NSDatePicker
    private var selectedDate: Date?

    override init() {
        let calendarDatePicker = CalendarDatePicker(frame: .zero)
        calendarDatePicker.datePickerStyle = .clockAndCalendar
        calendarDatePicker.datePickerElements = [.yearMonthDay]
        calendarDatePicker.isBordered = false
        calendarDatePicker.focusRingType = .none
        calendarDatePicker.sizeToFit()
        let unscaledSize = calendarDatePicker.frame.size
        calendarDatePicker.setFrameSize(NSSize(
            width: unscaledSize.width * Self.calendarScale,
            height: unscaledSize.height * Self.calendarScale
        ))
        calendarDatePicker.bounds = NSRect(origin: .zero, size: unscaledSize)
        datePicker = calendarDatePicker

        panel = CalendarPanel(
            contentRect: NSRect(origin: .zero, size: calendarDatePicker.frame.size),
            styleMask: [.titled, .utilityWindow],
            backing: .buffered,
            defer: true
        )
        formatKeyPanel = CalendarFormatKeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        super.init()

        panel.title = "日付を選択"
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        datePicker.frame = panel.contentView?.bounds ?? datePicker.frame
        panel.contentView?.addSubview(datePicker)
        panel.cancelAction = { [weak self] in
            self?.cancelSelection()
        }
        if let calendarDatePicker = datePicker as? CalendarDatePicker {
            calendarDatePicker.confirmAction = { [weak self] in
                self?.confirmSelection()
            }
            calendarDatePicker.cancelAction = { [weak self] in
                self?.cancelSelection()
            }
        }
        datePicker.target = self
        datePicker.action = #selector(selectDate(_:))
        formatKeyPanel.level = .popUpMenu
        formatKeyPanel.alphaValue = 0.01
        formatKeyPanel.isOpaque = false
        formatKeyPanel.backgroundColor = .clear
        formatKeyPanel.isReleasedWhenClosed = false
        formatKeyPanel.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary
        ]
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func runSelection(
        near anchorFrame: NSRect,
        returnTo previousApplication: NSRunningApplication?,
        initialDate: Date = Date()
    ) -> Date? {
        selectedDate = nil
        datePicker.dateValue = initialDate
        position(near: anchorFrame)

        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy == .prohibited {
            _ = NSApp.setActivationPolicy(.accessory)
        }
        NSRunningApplication.current.activate(
            options: [.activateIgnoringOtherApps]
        )
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(datePicker)

        let response = NSApp.runModal(for: panel)
        panel.orderOut(nil)
        if NSApp.activationPolicy() != previousPolicy {
            _ = NSApp.setActivationPolicy(previousPolicy)
        }
        previousApplication?.activate(options: [.activateIgnoringOtherApps])

        guard response == .OK else { return nil }
        return selectedDate
    }

    func hide() {
        if NSApp.modalWindow === panel {
            NSApp.abortModal()
        }
        panel.orderOut(nil)
        formatKeyPanel.orderOut(nil)
    }

    func runFormatSelection(
        candidateCount: Int,
        near anchorFrame: NSRect,
        returnTo previousApplication: NSRunningApplication?,
        selectionChanged: @escaping (Int?) -> Void
    ) -> Int? {
        guard candidateCount > 0 else { return nil }
        formatKeyPanel.candidateCount = candidateCount
        formatKeyPanel.selectedIndex = nil
        formatKeyPanel.selectionChanged = selectionChanged

        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy == .prohibited {
            _ = NSApp.setActivationPolicy(.accessory)
        }
        formatKeyPanel.setFrameOrigin(anchorFrame.origin)
        NSRunningApplication.current.activate(
            options: [.activateIgnoringOtherApps]
        )
        NSApp.activate(ignoringOtherApps: true)
        formatKeyPanel.makeKeyAndOrderFront(nil)
        formatKeyPanel.makeFirstResponder(formatKeyPanel)

        let response = NSApp.runModal(for: formatKeyPanel)
        let selectedIndex = formatKeyPanel.selectedIndex
        formatKeyPanel.orderOut(nil)
        formatKeyPanel.selectionChanged = nil
        if NSApp.activationPolicy() != previousPolicy {
            _ = NSApp.setActivationPolicy(previousPolicy)
        }
        previousApplication?.activate(options: [.activateIgnoringOtherApps])

        return response == .OK ? selectedIndex : nil
    }

    private func position(near anchorFrame: NSRect) {
        let resolvedAnchor = anchorFrame == .zero
            ? NSRect(origin: NSEvent.mouseLocation, size: NSSize(width: 1, height: 1))
            : anchorFrame
        let screens = NSScreen.screens
        let screen = screens.max { lhs, rhs in
            intersectionArea(lhs.frame, resolvedAnchor)
                < intersectionArea(rhs.frame, resolvedAnchor)
        }.flatMap {
            intersectionArea($0.frame, resolvedAnchor) > 0 ? $0 : nil
        } ?? nearestScreen(
            to: NSPoint(x: resolvedAnchor.midX, y: resolvedAnchor.midY),
            screens: screens
        ) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let size = panel.frame.size
        let x = min(
            max(resolvedAnchor.minX, visibleFrame.minX),
            visibleFrame.maxX - size.width
        )
        var y = resolvedAnchor.minY - size.height - 6
        if y < visibleFrame.minY {
            y = min(resolvedAnchor.maxY + 6, visibleFrame.maxY - size.height)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func intersectionArea(_ lhs: NSRect, _ rhs: NSRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private func nearestScreen(
        to point: NSPoint,
        screens: [NSScreen]
    ) -> NSScreen? {
        screens.min { lhs, rhs in
            squaredDistance(from: point, to: lhs.frame)
                < squaredDistance(from: point, to: rhs.frame)
        }
    }

    private func squaredDistance(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let x = min(max(point.x, rect.minX), rect.maxX)
        let y = min(max(point.y, rect.minY), rect.maxY)
        return pow(point.x - x, 2) + pow(point.y - y, 2)
    }

    @objc private func selectDate(_ sender: NSDatePicker) {
        confirmSelection()
    }

    private func confirmSelection() {
        selectedDate = datePicker.dateValue
        NSApp.stopModal(withCode: .OK)
    }

    private func cancelSelection() {
        selectedDate = nil
        NSApp.stopModal(withCode: .cancel)
    }
}
