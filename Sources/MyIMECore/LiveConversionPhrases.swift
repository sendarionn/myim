import Foundation

/// A phrase of a live conversion: what it shows and the kana it reads,
/// kept together so a position in the text is never taken for one in the
/// reading
public struct LiveConversionSegment: Equatable, Sendable {
    public var surface: String
    public var reading: String

    public init(surface: String, reading: String) {
        self.surface = surface
        self.reading = reading
    }

    /// Words joined into phrases: kana written as it reads, such as は, を
    /// or します, goes with the word before it, also where the converter
    /// puts it at the start of the next word, so 今日|は良い|転機 becomes
    /// 今日は|良い|転機
    public static func phrases(of words: [LiveConversionSegment]) -> [LiveConversionSegment] {
        var phrases: [LiveConversionSegment] = []
        for word in words where !word.reading.isEmpty {
            guard !phrases.isEmpty else {
                phrases.append(word)
                continue
            }
            let kana = word.surface.commonPrefix(with: word.reading)
            phrases[phrases.count - 1].surface += kana
            phrases[phrases.count - 1].reading += kana
            let rest = LiveConversionSegment(
                surface: String(word.surface.dropFirst(kana.count)),
                reading: String(word.reading.dropFirst(kana.count))
            )
            if !rest.reading.isEmpty {
                phrases.append(rest)
            }
        }
        return phrases
    }
}

/// The phrases of a live conversion being corrected: one phrase is
/// selected with the arrows, its range in the reading adjusted with Shift
/// and the arrows, and its conversion replaced. Phrases up to one corrected
/// by hand are fixed, so the conversion of what is typed next leaves them
public struct LiveConversionPhrases: Equatable, Sendable {
    public enum Edge: Equatable, Sendable {
        case left
        case right
    }

    public private(set) var segments: [LiveConversionSegment]
    /// Leading phrases corrected by hand, or before one that was
    public private(set) var fixedCount = 0
    public private(set) var selectedIndex: Int?
    /// The edge Shift and the arrows move, chosen by the first of them
    public private(set) var activeEdge: Edge?

    public init(segments: [LiveConversionSegment]) {
        self.segments = segments
    }

    public var text: String { segments.map(\.surface).joined() }
    public var reading: String { segments.map(\.reading).joined() }
    public var fixedSegments: [LiveConversionSegment] { Array(segments.prefix(fixedCount)) }
    public var fixedReading: String { fixedSegments.map(\.reading).joined() }
    public var isSelecting: Bool { selectedIndex != nil }
    public var hasCorrections: Bool { fixedCount > 0 }

    public var selectedSegment: LiveConversionSegment? {
        selectedIndex.map { segments[$0] }
    }

    /// The selected phrase's range in the text, in UTF-16 units for the
    /// marked text
    public var selectedTextRange: NSRange? {
        guard let selectedIndex else { return nil }
        let before = segments.prefix(selectedIndex).map(\.surface).joined()
        return NSRange(
            location: before.utf16.count,
            length: segments[selectedIndex].surface.utf16.count
        )
    }

    /// The conversion of the text typed after the fixed phrases
    public mutating func replaceUnfixed(with segments: [LiveConversionSegment]) {
        self.segments = fixedSegments + segments
        selectedIndex = nil
        activeEdge = nil
    }

    /// ← with nothing selected selects the last phrase, then the one before
    public mutating func selectPrevious() {
        guard !segments.isEmpty else { return }
        selectedIndex = selectedIndex.map { max($0 - 1, 0) } ?? segments.count - 1
        activeEdge = nil
    }

    public mutating func selectNext() {
        guard let selectedIndex else { return }
        self.selectedIndex = min(selectedIndex + 1, segments.count - 1)
        activeEdge = nil
    }

    public mutating func clearSelection() {
        selectedIndex = nil
        activeEdge = nil
    }

    /// A phrase beside the selection that lost a kana to it, whose
    /// conversion no longer fits and is to be converted again
    public private(set) var phraseToConvert: Int?

    public mutating func replaceSurface(at index: Int, with surface: String) {
        guard segments.indices.contains(index) else { return }
        segments[index].surface = surface
    }

    /// Shift and an arrow move one end of the selected phrase by one kana:
    /// the first of them picks the end, its opposite then shrinks it back.
    /// A phrase beside it that gives a kana is left to be converted again
    /// (`phraseToConvert`); one that takes a kana keeps its conversion with
    /// the kana after or before it. Returns whether the selection changed,
    /// so it is converted again
    @discardableResult
    public mutating func adjust(toward direction: Edge) -> Bool {
        phraseToConvert = nil
        guard let index = selectedIndex else { return false }
        let edge = activeEdge ?? direction
        activeEdge = edge
        switch (edge, direction) {
        case (.left, .left):
            guard index > 0 else { return false }
            let character = segments[index - 1].reading.removeLast()
            segments[index - 1].surface = segments[index - 1].reading
            segments[index].reading.insert(character, at: segments[index].reading.startIndex)
            segments[index].surface = segments[index].reading
            if segments[index - 1].reading.isEmpty {
                segments.remove(at: index - 1)
                selectedIndex = index - 1
                fixedCount = max(fixedCount - 1, 0)
            } else {
                phraseToConvert = index - 1
            }
        case (.left, .right):
            guard segments[index].reading.count > 1 else { return false }
            let character = segments[index].reading.removeFirst()
            segments[index].surface = segments[index].reading
            if index > 0 {
                segments[index - 1].reading.append(character)
                segments[index - 1].surface.append(character)
            } else {
                segments.insert(
                    LiveConversionSegment(surface: String(character), reading: String(character)),
                    at: 0
                )
                selectedIndex = 1
            }
        case (.right, .right):
            guard index + 1 < segments.count else { return false }
            let character = segments[index + 1].reading.removeFirst()
            segments[index + 1].surface = segments[index + 1].reading
            segments[index].reading.append(character)
            segments[index].surface = segments[index].reading
            if segments[index + 1].reading.isEmpty {
                segments.remove(at: index + 1)
            } else {
                phraseToConvert = index + 1
            }
        case (.right, .left):
            guard segments[index].reading.count > 1 else { return false }
            let character = segments[index].reading.removeLast()
            segments[index].surface = segments[index].reading
            if index + 1 < segments.count {
                segments[index + 1].reading.insert(character, at: segments[index + 1].reading.startIndex)
                segments[index + 1].surface.insert(character, at: segments[index + 1].surface.startIndex)
            } else {
                segments.append(LiveConversionSegment(surface: String(character), reading: String(character)))
            }
        }
        return true
    }

    /// Shows a conversion in place of the selected phrase while it is chosen
    public mutating func previewSelected(_ surface: String) {
        guard let selectedIndex else { return }
        segments[selectedIndex].surface = surface
    }

    /// The selected phrase takes the conversion chosen for it, and it and
    /// the phrases before it are fixed
    public mutating func commitSelected(_ surface: String) {
        guard let selectedIndex else { return }
        segments[selectedIndex].surface = surface
        fixedCount = max(fixedCount, selectedIndex + 1)
        clearSelection()
    }
}
