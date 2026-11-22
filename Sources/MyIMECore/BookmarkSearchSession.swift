import Foundation

public struct BookmarkSearchSession: Equatable, Sendable {
    public enum Stage: Equatable, Sendable {
        case inactive
        case loadingBookmarks
        case searching
        case loadingFormats
        case selectingFormat
    }

    public private(set) var stage: Stage = .inactive
    public private(set) var query = ""
    public private(set) var loadError: String?
    public private(set) var bookmarks: [BrowserBookmark] = []
    public private(set) var filteredBookmarks: [BrowserBookmark] = []
    public private(set) var selectedBookmarkIndex: Int?
    public private(set) var formatBookmark: BrowserBookmark?
    public private(set) var formats: [BookmarkFormatCandidate] = []
    public private(set) var selectedFormatIndex: Int?
    /// Romaji typed but not yet committed to the query; the list narrows by
    /// it as typed, so ASCII searches work without converting
    public private(set) var composition = ""
    /// The conversions of the composition while they are listed in place of
    /// the bookmarks
    public private(set) var conversionCandidates: [String]?
    public private(set) var selectedConversionIndex: Int?

    public init() {}

    public var isActive: Bool { stage != .inactive }
    public var isComposing: Bool { !composition.isEmpty }
    public var isConverting: Bool { conversionCandidates != nil }
    /// What the list is narrowed by
    public var searchText: String { query + composition }

    public var selectedConversion: String? {
        guard let selectedConversionIndex,
              let conversionCandidates,
              conversionCandidates.indices.contains(selectedConversionIndex) else {
            return nil
        }
        return conversionCandidates[selectedConversionIndex]
    }

    public mutating func appendComposition(_ text: String) {
        guard stage == .searching || stage == .loadingBookmarks else { return }
        composition += text
        conversionCandidates = nil
        selectedConversionIndex = nil
        refilter()
    }

    /// Lists the conversions of the composition, the first selected
    public mutating func beginConversion(_ candidates: [String]) {
        guard isSearching, isComposing, !candidates.isEmpty else { return }
        conversionCandidates = candidates
        selectedConversionIndex = 0
    }

    public mutating func moveConversionSelection(by offset: Int) {
        guard let conversionCandidates else { return }
        selectedConversionIndex = LinearCandidateNavigator.index(
            from: selectedConversionIndex,
            offset: offset,
            candidateCount: conversionCandidates.count
        )
    }

    public mutating func selectConversion(at index: Int?) {
        guard let conversionCandidates else { return }
        if let index, conversionCandidates.indices.contains(index) {
            selectedConversionIndex = index
        }
    }

    /// Adds the selected conversion, or the composition as typed when none
    /// is listed, to the query
    public mutating func commitComposition() {
        guard isComposing else { return }
        query += selectedConversion ?? composition
        composition = ""
        conversionCandidates = nil
        selectedConversionIndex = nil
        refilter()
    }

    /// Back from the conversions to the composition as typed
    public mutating func cancelConversion() {
        conversionCandidates = nil
        selectedConversionIndex = nil
    }

    public mutating func cancelComposition() {
        composition = ""
        cancelConversion()
        refilter()
    }

    /// Deletes from the composition first, then from the query
    public mutating func deleteBackward() {
        guard isSearching else { return }
        cancelConversion()
        if !composition.isEmpty {
            composition.removeLast()
        } else if !query.isEmpty {
            query.removeLast()
        }
        refilter()
    }

    public func conversionPageRange(pageSize: Int) -> Range<Int> {
        LinearCandidateNavigator.pageRange(
            containing: selectedConversionIndex,
            pageSize: pageSize,
            candidateCount: conversionCandidates?.count ?? 0
        )
    }

    private mutating func refilter() {
        if stage == .searching {
            applyQuery(preserving: nil)
        }
    }
    public var isSearching: Bool {
        stage == .loadingBookmarks || stage == .searching
    }
    public var isSelectingFormat: Bool {
        stage == .loadingFormats || stage == .selectingFormat
    }

    public var selectedBookmark: BrowserBookmark? {
        guard let selectedBookmarkIndex,
              filteredBookmarks.indices.contains(selectedBookmarkIndex) else {
            return nil
        }
        return filteredBookmarks[selectedBookmarkIndex]
    }

    public var selectedFormat: BookmarkFormatCandidate? {
        guard let selectedFormatIndex,
              formats.indices.contains(selectedFormatIndex) else { return nil }
        return formats[selectedFormatIndex]
    }

    public mutating func begin() {
        reset()
        stage = .loadingBookmarks
    }

    public mutating func replaceBookmarks(_ bookmarks: [BrowserBookmark]) {
        guard stage == .loadingBookmarks || stage == .searching else { return }
        self.bookmarks = bookmarks
        stage = .searching
        applyQuery(preserving: nil)
    }

    public mutating func failLoading(_ message: String) {
        guard stage == .loadingBookmarks else { return }
        loadError = message
        stage = .searching
        applyQuery(preserving: nil)
    }

    public mutating func updateQuery(_ query: String) {
        guard isSearching else { return }
        self.query = query
        if stage == .searching {
            applyQuery(preserving: nil)
        }
    }

    public mutating func moveBookmarkSelection(by offset: Int) {
        guard stage == .searching else { return }
        selectedBookmarkIndex = LinearCandidateNavigator.index(
            from: selectedBookmarkIndex,
            offset: offset,
            candidateCount: filteredBookmarks.count
        )
    }

    public mutating func selectBookmark(at index: Int?) {
        guard stage == .searching else { return }
        guard let index else {
            selectedBookmarkIndex = nil
            return
        }
        guard filteredBookmarks.indices.contains(index) else { return }
        selectedBookmarkIndex = index
    }

    @discardableResult
    public mutating func beginFormatLoading() -> BrowserBookmark? {
        guard stage == .searching, let bookmark = selectedBookmark else {
            return nil
        }
        formatBookmark = bookmark
        formats = []
        selectedFormatIndex = nil
        stage = .loadingFormats
        return bookmark
    }

    public func acceptsFormats(for bookmark: BrowserBookmark) -> Bool {
        stage == .loadingFormats && formatBookmark == bookmark
    }

    public mutating func replaceFormats(_ formats: [BookmarkFormatCandidate]) {
        guard stage == .loadingFormats else { return }
        self.formats = formats
        selectedFormatIndex = formats.isEmpty ? nil : 0
        stage = .selectingFormat
    }

    public mutating func moveFormatSelection(by offset: Int) {
        guard stage == .selectingFormat else { return }
        selectedFormatIndex = LinearCandidateNavigator.index(
            from: selectedFormatIndex,
            offset: offset,
            candidateCount: formats.count
        )
    }

    public mutating func selectFormat(at index: Int?) {
        guard stage == .selectingFormat else { return }
        guard let index else {
            selectedFormatIndex = nil
            return
        }
        guard formats.indices.contains(index) else { return }
        selectedFormatIndex = index
    }

    public mutating func returnToSearch() {
        guard isSelectingFormat else { return }
        let previous = formatBookmark
        formatBookmark = nil
        formats = []
        selectedFormatIndex = nil
        stage = .searching
        applyQuery(preserving: previous)
    }

    /// Why no bookmark is listed: nothing synced from the extension yet, a
    /// synced list with no bookmarks, or no bookmark matching the query
    public var emptyMessage: String? {
        guard stage == .searching, filteredBookmarks.isEmpty else {
            return nil
        }
        if let loadError { return loadError }
        if bookmarks.isEmpty {
            return Self.syncedButEmptyMessage
        }
        return "「\(searchText)」に一致するブックマークがありません"
    }

    public static let notSyncedMessage =
        "Chrome拡張機能からまだ同期されていません"
    public static let syncedButEmptyMessage =
        "同期済みのブックマークが0件です"

    public func bookmarkPageRange(pageSize: Int) -> Range<Int> {
        LinearCandidateNavigator.pageRange(
            containing: selectedBookmarkIndex,
            pageSize: pageSize,
            candidateCount: filteredBookmarks.count
        )
    }

    public func formatPageRange(pageSize: Int) -> Range<Int> {
        LinearCandidateNavigator.pageRange(
            containing: selectedFormatIndex,
            pageSize: pageSize,
            candidateCount: formats.count
        )
    }

    public mutating func reset() {
        stage = .inactive
        query = ""
        composition = ""
        conversionCandidates = nil
        selectedConversionIndex = nil
        loadError = nil
        bookmarks = []
        filteredBookmarks = []
        selectedBookmarkIndex = nil
        formatBookmark = nil
        formats = []
        selectedFormatIndex = nil
    }

    private mutating func applyQuery(preserving bookmark: BrowserBookmark?) {
        filteredBookmarks = bookmarks.filter { $0.matches(searchText) }
        if let bookmark,
           let index = filteredBookmarks.firstIndex(of: bookmark) {
            selectedBookmarkIndex = index
        } else {
            selectedBookmarkIndex = filteredBookmarks.isEmpty ? nil : 0
        }
    }
}
