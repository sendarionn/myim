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

    /// The converter's words made phrases. A word that starts with a
    /// particle or auxiliary (`functionWords`) gives the kana it starts
    /// with to the phrase before, so 強|は良い becomes 強は|良い and 準備し|ます
    /// becomes 準備します. Another word that starts with two or more kana
    /// written as they read and goes on in kanji is split there, so いい天気
    /// becomes いい|天気 and この本 この|本, while お茶 stays whole
    public static func phrases(
        of words: [LiveConversionSegment],
        functionWords: [Bool] = []
    ) -> [LiveConversionSegment] {
        var phrases: [LiveConversionSegment] = []
        for (index, word) in words.enumerated() where !word.reading.isEmpty {
            // Letters, digits and symbols kept as typed, which the
            // converter gives a character at a time, stay one phrase
            if word.isKeptAsTyped, let last = phrases.last, last.isKeptAsTyped {
                phrases[phrases.count - 1].surface += word.surface
                phrases[phrases.count - 1].reading += word.reading
                continue
            }
            let isFunctionWord = functionWords.indices.contains(index) && functionWords[index]
            let kana = word.surface.commonPrefix(with: word.reading)
            let rest = LiveConversionSegment(
                surface: String(word.surface.dropFirst(kana.count)),
                reading: String(word.reading.dropFirst(kana.count))
            )
            if isFunctionWord, !phrases.isEmpty, !kana.isEmpty {
                phrases[phrases.count - 1].surface += kana
                phrases[phrases.count - 1].reading += kana
                if !rest.reading.isEmpty {
                    phrases.append(rest)
                }
            } else if !isFunctionWord, kana.count >= 2, !rest.reading.isEmpty {
                phrases.append(LiveConversionSegment(surface: kana, reading: kana))
                phrases.append(rest)
            } else {
                phrases.append(word)
            }
        }
        return phrases
    }

    private var isKeptAsTyped: Bool {
        surface == reading && surface.unicodeScalars.allSatisfy(\.isASCII)
    }
}

/// A live conversion chosen among the candidates and shown in place of the
/// letters, to be corrected before it is committed. ← and → move a cursor
/// in its text, Shift with them selects from it as in a text field, and
/// the selection is converted again from the kana it reads
public struct LiveConversionPreview: Equatable, Sendable {
    public private(set) var segments: [LiveConversionSegment]
    /// In characters of `text`; at its end to begin with
    public private(set) var cursor: Int
    /// Where the selection began, while there is one
    public private(set) var anchor: Int?

    public init(segments: [LiveConversionSegment]) {
        self.segments = segments.filter { !$0.surface.isEmpty || !$0.reading.isEmpty }
        cursor = self.segments.map(\.surface.count).reduce(0, +)
    }

    public var text: String { segments.map(\.surface).joined() }
    public var reading: String { segments.map(\.reading).joined() }
    private var length: Int { segments.map(\.surface.count).reduce(0, +) }

    /// The selected characters of `text`, if any are
    public var selection: Range<Int>? {
        guard let anchor, anchor != cursor else { return nil }
        return min(anchor, cursor)..<max(anchor, cursor)
    }

    /// The selection in UTF-16 units, for the marked text
    public var selectedTextRange: NSRange? {
        selection.map { utf16Range($0) }
    }

    /// The cursor in UTF-16 units
    public var cursorOffset: Int { utf16Range(0..<cursor).length }

    /// ← and → move the cursor, or from a selection to its end that way
    public mutating func moveCursor(by offset: Int) {
        if let selection {
            cursor = offset < 0 ? selection.lowerBound : selection.upperBound
        } else {
            cursor = min(max(cursor + offset, 0), length)
        }
        anchor = nil
    }

    /// Shift with ← and → moves the cursor and keeps where the selection
    /// began
    public mutating func extendSelection(by offset: Int) {
        if anchor == nil { anchor = cursor }
        cursor = min(max(cursor + offset, 0), length)
        if anchor == cursor { anchor = nil }
    }

    public mutating func clearSelection() {
        anchor = nil
    }

    /// The part a selection converts again: the selection widened to where
    /// the text can be told from its reading, as the end of a phrase or
    /// kana written as it reads, with the kana that part reads
    public var conversionTarget: (range: Range<Int>, reading: String)? {
        guard let selection else { return nil }
        let start = position(selection.lowerBound, widening: .backward)
        let end = position(selection.upperBound, widening: .forward)
        guard start.text < end.text else { return nil }
        let reading = Array(self.reading)
        return (start.text..<end.text, String(reading[start.reading..<end.reading]))
    }

    /// The selection, widened as `conversionTarget`, takes `surface`.
    /// Kept selected, it is a conversion being chosen; otherwise the cursor
    /// goes after it
    public mutating func replaceSelection(with surface: String, keepsSelected: Bool = false) {
        guard let selection else { return }
        let start = position(selection.lowerBound, widening: .backward)
        let end = position(selection.upperBound, widening: .forward)
        guard start.text < end.text else { return }
        let allReading = Array(reading)
        var replaced: [LiveConversionSegment] = []
        var offset = 0
        var readingOffset = 0
        for segment in segments {
            let range = offset..<(offset + segment.surface.count)
            let readingRange = readingOffset..<(readingOffset + segment.reading.count)
            offset = range.upperBound
            readingOffset = readingRange.upperBound
            if range.upperBound <= start.text || range.lowerBound >= end.text {
                replaced.append(segment)
                continue
            }
            if range.lowerBound < start.text {
                replaced.append(LiveConversionSegment(
                    surface: String(segment.surface.prefix(start.text - range.lowerBound)),
                    reading: String(segment.reading.prefix(start.reading - readingRange.lowerBound))
                ))
            }
            if range.lowerBound <= start.text {
                replaced.append(LiveConversionSegment(
                    surface: surface,
                    reading: String(allReading[start.reading..<end.reading])
                ))
            }
            if range.upperBound > end.text {
                replaced.append(LiveConversionSegment(
                    surface: String(segment.surface.suffix(range.upperBound - end.text)),
                    reading: String(segment.reading.suffix(readingRange.upperBound - end.reading))
                ))
            }
        }
        segments = replaced.filter { !$0.surface.isEmpty || !$0.reading.isEmpty }
        cursor = start.text + surface.count
        anchor = keepsSelected && !surface.isEmpty ? start.text : nil
    }

    private enum Widening {
        case backward
        case forward
    }

    /// A position in the text and the reading. One inside a phrase stays
    /// where the kana before or after it are written as they read, and
    /// otherwise moves to the phrase's start or end
    private func position(_ text: Int, widening: Widening) -> (text: Int, reading: Int) {
        var offset = 0
        var readingOffset = 0
        for segment in segments {
            let surface = Array(segment.surface)
            let end = offset + surface.count
            if text <= end {
                let inside = text - offset
                let kana = Array(segment.reading)
                let prefix = zip(surface, kana).prefix { $0 == $1 }.count
                let suffix = zip(surface.reversed(), kana.reversed()).prefix { $0 == $1 }.count
                if inside <= prefix {
                    return (text, readingOffset + inside)
                }
                if surface.count - inside <= suffix {
                    return (text, readingOffset + kana.count - (surface.count - inside))
                }
                return widening == .backward
                    ? (offset, readingOffset)
                    : (end, readingOffset + kana.count)
            }
            offset = end
            readingOffset += segment.reading.count
        }
        return (offset, readingOffset)
    }

    private func utf16Range(_ range: Range<Int>) -> NSRange {
        let characters = Array(text)
        let before = String(characters[0..<range.lowerBound]).utf16.count
        return NSRange(
            location: before,
            length: String(characters[range]).utf16.count
        )
    }
}
