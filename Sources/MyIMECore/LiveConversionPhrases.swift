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

    /// The selected part to be converted again: exactly the characters
    /// selected, with the kana they read. Kept from when its conversions
    /// are listed, so each of them and the one taken replace the same part
    public struct Target: Equatable, Sendable {
        public let range: Range<Int>
        public let readingRange: Range<Int>
        public let original: String
        public let reading: String
    }

    /// The selection as a part to convert again, or nil where its ends
    /// cannot be told in the reading. An end inside a phrase is found where
    /// the kana written in it meet the reading, hiragana and katakana alike;
    /// one inside kanji is found when `converts` takes the kana each side of
    /// it to the kanji each side, as てん|き to 天|気. The selection is never
    /// widened
    public func conversionTarget(
        converts: (_ reading: String, _ surface: String) -> Bool = { _, _ in false }
    ) -> Target? {
        guard let selection,
              let start = readingOffset(at: selection.lowerBound, converts: converts),
              let end = readingOffset(at: selection.upperBound, converts: converts),
              start < end else { return nil }
        let reading = Array(self.reading)
        return Target(
            range: selection,
            readingRange: start..<end,
            original: String(Array(text)[selection]),
            reading: String(reading[start..<end])
        )
    }

    /// `target` takes `surface`, and everything outside it stays as it is.
    /// Kept selected, it is a conversion being chosen; otherwise the cursor
    /// goes after it
    public func replacing(_ target: Target, with surface: String, keepsSelected: Bool = false) -> LiveConversionPreview {
        var replaced: [LiveConversionSegment] = []
        var offset = 0
        var readingOffset = 0
        var inserted = false
        func insert() {
            guard !inserted else { return }
            inserted = true
            replaced.append(LiveConversionSegment(surface: surface, reading: target.reading))
        }
        for segment in segments {
            let range = offset..<(offset + segment.surface.count)
            let readingRange = readingOffset..<(readingOffset + segment.reading.count)
            offset = range.upperBound
            readingOffset = readingRange.upperBound
            if range.upperBound <= target.range.lowerBound {
                replaced.append(segment)
                continue
            }
            if range.lowerBound >= target.range.upperBound {
                insert()
                replaced.append(segment)
                continue
            }
            if range.lowerBound < target.range.lowerBound {
                replaced.append(LiveConversionSegment(
                    surface: String(segment.surface.prefix(target.range.lowerBound - range.lowerBound)),
                    reading: String(segment.reading.prefix(target.readingRange.lowerBound - readingRange.lowerBound))
                ))
            }
            insert()
            if range.upperBound > target.range.upperBound {
                replaced.append(LiveConversionSegment(
                    surface: String(segment.surface.suffix(range.upperBound - target.range.upperBound)),
                    reading: String(segment.reading.suffix(readingRange.upperBound - target.readingRange.upperBound))
                ))
            }
        }
        insert()
        var preview = self
        preview.segments = replaced.filter { !$0.surface.isEmpty || !$0.reading.isEmpty }
        preview.cursor = target.range.lowerBound + surface.count
        preview.anchor = keepsSelected && !surface.isEmpty ? target.range.lowerBound : nil
        return preview
    }

    /// The offset in the reading of a position in the text
    private func readingOffset(at position: Int, converts: (String, String) -> Bool) -> Int? {
        var offset = 0
        var readingStart = 0
        for segment in segments {
            let surface = Array(segment.surface)
            if position <= offset + surface.count {
                let inside = position - offset
                if inside == 0 { return readingStart }
                if inside == surface.count { return readingStart + segment.reading.count }
                return Self.readingOffset(
                    at: inside,
                    surface: surface,
                    reading: Array(segment.reading),
                    converts: converts
                ).map { readingStart + $0 }
            }
            offset += surface.count
            readingStart += segment.reading.count
        }
        return nil
    }

    /// Within a phrase: the offsets in the reading every way of reading it
    /// gives the position, where a character written as it reads matches
    /// one kana and any other reads one or more. One offset is the answer;
    /// with more, inside kanji, the one `converts` confirms each side of
    static func readingOffset(
        at position: Int,
        surface: [Character],
        reading: [Character],
        converts: (String, String) -> Bool
    ) -> Int? {
        let kana = reading.map(normalized)
        let written = surface.map(normalized)
        func readsAsWritten(_ character: Character) -> Bool {
            let scalars = String(character).unicodeScalars
            return scalars.allSatisfy {
                $0.isASCII || (0x3041...0x309F).contains($0.value) || $0.value == 0x30FC
                    || (0x3000...0x303F).contains($0.value) || (0xFF01...0xFF5E).contains($0.value)
            }
        }
        let isKana = written.map(readsAsWritten)
        // Offsets the text up to each position can read to
        var forward = Array(repeating: Set<Int>(), count: surface.count + 1)
        forward[0] = [0]
        for index in surface.indices {
            for offset in forward[index] {
                if isKana[index] {
                    if offset < kana.count, kana[offset] == written[index] {
                        forward[index + 1].insert(offset + 1)
                    }
                } else {
                    for end in (offset + 1)...max(offset + 1, kana.count) where end <= kana.count {
                        forward[index + 1].insert(end)
                    }
                }
            }
        }
        // Offsets the text from each position to its end can read from
        var backward = Array(repeating: Set<Int>(), count: surface.count + 1)
        backward[surface.count] = [kana.count]
        for index in surface.indices.reversed() {
            for offset in backward[index + 1] {
                if isKana[index] {
                    if offset > 0, kana[offset - 1] == written[index] {
                        backward[index].insert(offset - 1)
                    }
                } else {
                    for start in 0..<offset {
                        backward[index].insert(start)
                    }
                }
            }
        }
        let offsets = forward[position].intersection(backward[position]).sorted()
        if offsets.count == 1 { return offsets[0] }
        guard offsets.count > 1 else { return nil }
        // Inside kanji: the kanji each side, up to kana written as they
        // read or the phrase's ends, which must be read one way
        var runStart = position
        while runStart > 0, !isKana[runStart - 1] { runStart -= 1 }
        var runEnd = position
        while runEnd < surface.count, !isKana[runEnd] { runEnd += 1 }
        let starts = forward[runStart].intersection(backward[runStart])
        let ends = forward[runEnd].intersection(backward[runEnd])
        guard starts.count == 1, ends.count == 1,
              let readingStart = starts.first, let readingEnd = ends.first else { return nil }
        let confirmed = offsets.filter { offset in
            readingStart < offset && offset < readingEnd
                && converts(String(reading[readingStart..<offset]), String(surface[runStart..<position]))
                && converts(String(reading[offset..<readingEnd]), String(surface[position..<runEnd]))
        }
        return confirmed.count == 1 ? confirmed[0] : nil
    }

    /// Katakana compared as hiragana
    private static func normalized(_ character: Character) -> Character {
        let scalars = String(character).unicodeScalars.map { scalar -> Unicode.Scalar in
            (0x30A1...0x30F6).contains(scalar.value)
                ? Unicode.Scalar(scalar.value - 0x60) ?? scalar
                : scalar
        }
        return Character(String(String.UnicodeScalarView(scalars)))
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
