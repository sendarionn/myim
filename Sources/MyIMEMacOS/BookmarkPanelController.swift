import AppKit

/// The bookmark search's own panel, listing the bookmarks and then their
/// formats. It stays shown while the search text is typed and converted,
/// beside the conversion candidates so the two never overlap
final class BookmarkPanelController {
    private let panel = CandidatePanelController()
    private static let spacing: CGFloat = 8

    var onSelectionChanged: ((Int?) -> Void)? {
        get { panel.onSelectionChanged }
        set { panel.onSelectionChanged = newValue }
    }

    var isVisible: Bool { panel.isVisible }
    var visibleFrame: NSRect? { panel.visibleFrame }

    /// `occupiedFrame` is what the conversion panels cover now; without it
    /// the panel opens below the input position as the candidates do
    /// `bookmarkRows` tells which rows are bookmarks, marked with the
    /// bookmark symbol; formats and messages are not
    func show(
        candidates: [String],
        bookmarkRows: [Bool] = [],
        selectedIndex: Int?,
        caption: String,
        reservesEmptyRow: Bool = false,
        near anchorFrame: NSRect,
        beside occupiedFrame: NSRect?
    ) {
        panel.show(
            candidates: candidates,
            bookmarkIndicators: bookmarkRows,
            selectedIndex: selectedIndex,
            near: anchorFrame,
            caption: caption,
            reservesEmptyRow: reservesEmptyRow,
            minimumPanelText: "ブックマーク検索"
        )
        if let occupiedFrame {
            panel.placeBeside(occupiedFrame, spacing: Self.spacing)
        }
    }

    func hide() {
        panel.onSelectionChanged = nil
        panel.hide()
    }
}
