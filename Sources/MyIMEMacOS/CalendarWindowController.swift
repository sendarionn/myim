@preconcurrency import AppKit
import MyIMECore

private final class CalendarPanel: NSPanel {
    var cancelAction: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        cancelAction?()
    }

    override func resignKey() {
        super.resignKey()
        guard NSApp.modalWindow === self else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, NSApp.modalWindow === self else { return }
            self.cancelAction?()
        }
    }
}

private final class CalendarGridView: NSView {
    var confirmAction: (() -> Void)?
    var cancelAction: (() -> Void)?
    private(set) var selectedDate = Date()
    private var displayedMonth = Date()
    private var calendar: Calendar = {
        var value = Calendar.current
        value.firstWeekday = 1
        return value
    }()
    private let titleLabel = NSButton(title: "", target: nil, action: nil)
    private let yearField = NSTextField()
    private let monthField = NSTextField()
    private let applyDateButton = NSButton(title: "移動", target: nil, action: nil)
    private let previousYearButton = NSButton(title: "«", target: nil, action: nil)
    private let previousButton = NSButton(title: "‹", target: nil, action: nil)
    private let nextButton = NSButton(title: "›", target: nil, action: nil)
    private let nextYearButton = NSButton(title: "»", target: nil, action: nil)
    private let shortcutLabel = NSTextField(
        labelWithString: "矢印 移動　⌥←→ 月　⌥↑↓ 年\nReturn 確定　Esc 閉じる"
    )
    private var weekdayLabels: [NSTextField] = []
    private var dayButtons: [NSButton] = []
    private var dates: [Date] = []

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.isBordered = false
        titleLabel.bezelStyle = .inline
        titleLabel.target = self
        titleLabel.action = #selector(showYearMonthMenu)
        titleLabel.toolTip = "年と月を選択"
        addSubview(titleLabel)
        for field in [yearField, monthField] {
            field.alignment = .center
            field.font = .systemFont(ofSize: 12)
            field.focusRingType = .none
            field.isHidden = true
            field.target = self
            field.action = #selector(applyEnteredYearMonth)
            addSubview(field)
        }
        yearField.placeholderString = "年"
        monthField.placeholderString = "月"
        yearField.nextKeyView = monthField
        monthField.nextKeyView = yearField
        applyDateButton.font = .systemFont(ofSize: 11)
        applyDateButton.bezelStyle = .rounded
        applyDateButton.isHidden = true
        applyDateButton.target = self
        applyDateButton.action = #selector(applyEnteredYearMonth)
        addSubview(applyDateButton)
        for button in [previousYearButton, previousButton, nextButton, nextYearButton] {
            button.bezelStyle = .inline
            button.isBordered = false
            button.font = .systemFont(ofSize: 17)
            addSubview(button)
        }
        previousYearButton.target = self
        previousYearButton.action = #selector(showPreviousYear)
        previousButton.target = self
        previousButton.action = #selector(showPreviousMonth)
        nextButton.target = self
        nextButton.action = #selector(showNextMonth)
        nextYearButton.target = self
        nextYearButton.action = #selector(showNextYear)
        shortcutLabel.alignment = .center
        shortcutLabel.font = .systemFont(ofSize: 9)
        shortcutLabel.textColor = .secondaryLabelColor
        shortcutLabel.maximumNumberOfLines = 2
        shortcutLabel.lineBreakMode = .byWordWrapping
        addSubview(shortcutLabel)

        for name in ["日", "月", "火", "水", "木", "金", "土"] {
            let label = NSTextField(labelWithString: name)
            label.alignment = .center
            label.font = .systemFont(ofSize: 11, weight: .medium)
            weekdayLabels.append(label)
            addSubview(label)
        }
        for index in 0..<42 {
            let button = NSButton(title: "", target: self, action: #selector(selectDay(_:)))
            button.tag = index
            button.bezelStyle = .rounded
            button.isBordered = false
            button.font = .systemFont(ofSize: 13)
            button.focusRingType = .none
            dayButtons.append(button)
            addSubview(button)
        }
    }

    required init?(coder: NSCoder) { nil }

    func setDate(_ date: Date) {
        selectedDate = date
        displayedMonth = CalendarGridNavigator.monthStart(
            containing: date,
            calendar: calendar
        ) ?? date
        reload()
    }

    override func layout() {
        super.layout()
        let padding: CGFloat = 9
        let headerHeight: CGFloat = 28
        let weekdayHeight: CGFloat = 18
        let footerHeight: CGFloat = 28
        let gridTop = bounds.height - padding - headerHeight - weekdayHeight
        let cellWidth = (bounds.width - padding * 2) / 7
        let cellHeight = (gridTop - padding - footerHeight) / 6
        let buttonWidth: CGFloat = 24
        let headerY = bounds.height - padding - headerHeight
        previousYearButton.frame = NSRect(x: padding, y: headerY, width: buttonWidth, height: headerHeight)
        previousButton.frame = NSRect(x: padding + buttonWidth, y: headerY, width: buttonWidth, height: headerHeight)
        nextYearButton.frame = NSRect(x: bounds.width - padding - buttonWidth, y: headerY, width: buttonWidth, height: headerHeight)
        nextButton.frame = NSRect(x: bounds.width - padding - buttonWidth * 2, y: headerY, width: buttonWidth, height: headerHeight)
        titleLabel.frame = NSRect(x: padding + buttonWidth * 2, y: headerY, width: bounds.width - padding * 2 - buttonWidth * 4, height: headerHeight)
        let inputX = padding + buttonWidth * 2
        yearField.frame = NSRect(x: inputX, y: headerY + 3, width: 50, height: headerHeight - 6)
        monthField.frame = NSRect(x: inputX + 53, y: headerY + 3, width: 32, height: headerHeight - 6)
        applyDateButton.frame = NSRect(x: inputX + 88, y: headerY + 1, width: 38, height: headerHeight - 2)
        shortcutLabel.frame = NSRect(x: padding, y: 2, width: bounds.width - padding * 2, height: footerHeight)
        for column in 0..<7 {
            weekdayLabels[column].frame = NSRect(x: padding + CGFloat(column) * cellWidth, y: gridTop, width: cellWidth, height: weekdayHeight)
        }
        for index in 0..<42 {
            let row = index / 7
            let column = index % 7
            dayButtons[index].frame = NSRect(
                x: padding + CGFloat(column) * cellWidth,
                y: gridTop - CGFloat(row + 1) * cellHeight,
                width: cellWidth,
                height: cellHeight
            )
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            confirmAction?()
        case 53:
            cancelAction?()
        case 123, 124:
            let direction = event.keyCode == 123 ? -1 : 1
            if event.modifierFlags.contains(.option) {
                change(component: .month, by: direction)
                return
            }
            if let move = CalendarGridNavigator.horizontalMove(
                from: selectedDate,
                displayedMonth: displayedMonth,
                direction: direction,
                calendar: calendar
            ) {
                selectedDate = move.date
                displayedMonth = move.displayedMonth
                reload()
            }
        case 125, 126:
            if event.modifierFlags.contains(.option) {
                change(component: .year, by: event.keyCode == 125 ? 1 : -1)
                return
            }
            let days = event.keyCode == 125 ? 7 : -7
            if let date = calendar.date(byAdding: .day, value: days, to: selectedDate) {
                selectedDate = date
                if !calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
                    displayedMonth = CalendarGridNavigator.monthStart(containing: date, calendar: calendar) ?? date
                }
                reload()
            }
        default:
            break
        }
    }

    private func reload() {
        dates = CalendarGridNavigator.gridDates(displayedMonth: displayedMonth, calendar: calendar)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        titleLabel.title = formatter.string(from: displayedMonth)
        for (index, button) in dayButtons.enumerated() where index < dates.count {
            let date = dates[index]
            button.title = String(calendar.component(.day, from: date))
            let inMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
            let isToday = calendar.isDateInToday(date)
            button.contentTintColor = isToday
                ? .controlAccentColor
                : (inMonth ? .labelColor : .tertiaryLabelColor)
            button.font = .systemFont(ofSize: 13, weight: isToday ? .bold : .regular)
            button.wantsLayer = true
            button.layer?.cornerRadius = 5
            button.layer?.borderWidth = isToday ? 1.5 : 0
            button.layer?.borderColor = isToday ? NSColor.controlAccentColor.cgColor : nil
            button.isBordered = calendar.isDate(date, inSameDayAs: selectedDate)
            button.bezelColor = button.isBordered ? .controlAccentColor : nil
        }
        needsDisplay = true
    }

    @objc private func selectDay(_ sender: NSButton) {
        guard dates.indices.contains(sender.tag) else { return }
        selectedDate = dates[sender.tag]
        reload()
        confirmAction?()
    }

    @objc private func showPreviousMonth() { changeMonth(by: -1) }
    @objc private func showNextMonth() { changeMonth(by: 1) }
    @objc private func showPreviousYear() { change(component: .year, by: -1) }
    @objc private func showNextYear() { change(component: .year, by: 1) }

    @objc private func showYearMonthMenu() {
        yearField.stringValue = String(calendar.component(.year, from: displayedMonth))
        monthField.stringValue = String(calendar.component(.month, from: displayedMonth))
        titleLabel.isHidden = true
        yearField.isHidden = false
        monthField.isHidden = false
        applyDateButton.isHidden = false
        window?.makeFirstResponder(yearField)
        yearField.selectText(nil)
    }

    @objc private func applyEnteredYearMonth() {
        guard let year = Int(yearField.stringValue),
              let month = Int(monthField.stringValue),
              let move = CalendarGridNavigator.selection(
                  date: selectedDate,
                  year: year,
                  month: month,
                  calendar: calendar
              )
        else { return }
        selectedDate = move.date
        displayedMonth = move.displayedMonth
        titleLabel.isHidden = false
        yearField.isHidden = true
        monthField.isHidden = true
        applyDateButton.isHidden = true
        window?.makeFirstResponder(self)
        reload()
    }

    private func changeMonth(by offset: Int) {
        change(component: .month, by: offset)
    }

    private func change(component: Calendar.Component, by offset: Int) {
        guard let move = CalendarGridNavigator.shiftedSelection(
            date: selectedDate,
            displayedMonth: displayedMonth,
            component: component,
            value: offset,
            calendar: calendar
        ) else { return }
        displayedMonth = move.displayedMonth
        selectedDate = move.date
        reload()
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
    private let panel: CalendarPanel
    private let formatKeyPanel: CalendarFormatKeyPanel
    private let calendarView: CalendarGridView
    private var selectedDate: Date?
    private var outsideLocalMonitor: Any?
    private var outsideGlobalMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?
    private var outsideClickTimer: Timer?

    override init() {
        let gridSize = NSSize(width: 240, height: 234)
        let calendarGrid = CalendarGridView(frame: NSRect(origin: .zero, size: gridSize))
        calendarView = calendarGrid

        panel = CalendarPanel(
            contentRect: NSRect(origin: .zero, size: gridSize),
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
        calendarView.frame = panel.contentView?.bounds ?? calendarView.frame
        calendarView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(calendarView)
        panel.cancelAction = { [weak self] in
            self?.cancelSelection()
        }
        calendarView.confirmAction = { [weak self] in
            self?.confirmSelection()
        }
        calendarView.cancelAction = { [weak self] in
            self?.cancelSelection()
        }
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
        calendarView.setDate(initialDate)
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
        panel.makeFirstResponder(calendarView)
        startOutsideClickMonitoring()

        let response = NSApp.runModal(for: panel)
        stopOutsideClickMonitoring()
        panel.orderOut(nil)
        if NSApp.activationPolicy() != previousPolicy {
            _ = NSApp.setActivationPolicy(previousPolicy)
        }
        previousApplication?.activate(options: [.activateIgnoringOtherApps])

        guard response == .OK else { return nil }
        return selectedDate
    }

    func hide() {
        stopOutsideClickMonitoring()
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

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()
        outsideLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            self?.cancelIfClickIsOutsideCalendar()
            return event
        }
        outsideGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.cancelIfClickIsOutsideCalendar()
            }
        }
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.cancelSelectionIfCalendarIsRunning()
        }
        outsideClickTimer = Timer.scheduledTimer(
            withTimeInterval: 0.02,
            repeats: true
        ) { [weak self] _ in
            guard NSEvent.pressedMouseButtons & 0b11 != 0 else { return }
            self?.cancelIfClickIsOutsideCalendar()
        }
    }

    private func stopOutsideClickMonitoring() {
        if let monitor = outsideLocalMonitor {
            NSEvent.removeMonitor(monitor)
            outsideLocalMonitor = nil
        }
        if let monitor = outsideGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            outsideGlobalMonitor = nil
        }
        if let observer = resignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            resignActiveObserver = nil
        }
        outsideClickTimer?.invalidate()
        outsideClickTimer = nil
    }

    private func cancelIfClickIsOutsideCalendar() {
        guard panel.isVisible,
              NSApp.modalWindow === panel,
              !panel.frame.contains(NSEvent.mouseLocation)
        else { return }
        cancelSelection()
    }

    private func cancelSelectionIfCalendarIsRunning() {
        guard panel.isVisible, NSApp.modalWindow === panel else { return }
        cancelSelection()
    }

    private func confirmSelection() {
        selectedDate = calendarView.selectedDate
        NSApp.stopModal(withCode: .OK)
    }

    private func cancelSelection() {
        stopOutsideClickMonitoring()
        selectedDate = nil
        NSApp.stopModal(withCode: .cancel)
    }
}
