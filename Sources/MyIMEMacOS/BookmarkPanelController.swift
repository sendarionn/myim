import AppKit

/// The bookmark search's own panels: the titles found, and beside them the
/// formats of the chosen bookmark. The titles stay shown while the search
/// text is typed and converted and while a format is chosen
final class BookmarkPanelController {
    private let listPanel = CandidatePanelController()
    private let formatPanel = CandidatePanelController()
    private static let spacing: CGFloat = 8

    var onListSelectionChanged: ((Int?) -> Void)? {
        get { listPanel.onSelectionChanged }
        set { listPanel.onSelectionChanged = newValue }
    }

    var onFormatSelectionChanged: ((Int?) -> Void)? {
        get { formatPanel.onSelectionChanged }
        set { formatPanel.onSelectionChanged = newValue }
    }

    var isVisible: Bool { listPanel.isVisible }

    /// Both panels together, which the preview and other panels avoid
    var visibleFrame: NSRect? {
        switch (listPanel.visibleFrame, formatPanel.visibleFrame) {
        case let (list?, format?): list.union(format)
        case let (list?, nil): list
        case let (nil, format?): format
        case (nil, nil): nil
        }
    }

    /// `occupiedFrame` is what the conversion panels cover now; without it
    /// the titles open below the input position as the candidates do
    func showList(
        candidates: [String],
        selectedIndex: Int?,
        reservesEmptyRow: Bool = false,
        near anchorFrame: NSRect,
        beside occupiedFrame: NSRect?
    ) {
        listPanel.show(
            candidates: candidates,
            selectedIndex: selectedIndex,
            near: anchorFrame,
            reservesEmptyRow: reservesEmptyRow
        )
        if let occupiedFrame {
            listPanel.placeBeside(occupiedFrame, spacing: Self.spacing)
        }
        if formatPanel.isVisible {
            formatPanel.placeBeside(listPanel.frame, spacing: Self.spacing)
        }
    }

    /// The formats beside the titles, which stay as they are
    func showFormats(
        candidates: [String],
        selectedIndex: Int?,
        reservesEmptyRow: Bool = false
    ) {
        formatPanel.show(
            candidates: candidates,
            selectedIndex: selectedIndex,
            near: listPanel.frame,
            reservesEmptyRow: reservesEmptyRow
        )
        formatPanel.placeBeside(listPanel.frame, spacing: Self.spacing)
    }

    func hideFormats() {
        formatPanel.onSelectionChanged = nil
        formatPanel.hide()
    }

    func hide() {
        hideFormats()
        listPanel.onSelectionChanged = nil
        listPanel.hide()
    }
}
