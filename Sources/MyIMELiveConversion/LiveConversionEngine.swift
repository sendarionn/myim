import Foundation
import KanaKanjiConverterModule
import MyIMECore

/// The result of converting a whole composition at once
public struct LiveConversionResult: Equatable, Sendable {
    /// The kana the typed letters read as, with words that are not romaji
    /// as typed
    public let reading: String
    /// How far the letters were read as kana
    public let status: LiveConversionInput.Reading
    /// Conversions of the whole reading, best first
    public let candidates: [String]
    /// Each of them in phrases with the kana each reads
    public let phrases: [[LiveConversionSegment]]
}

/// The live conversion: the whole composition converted as
/// one, by AzooKeyKanaKanjiConverter with its dictionary. It learns
/// nothing and keeps nothing of the user's; one engine is used from one
/// serial queue
public final class LiveConversionEngine: @unchecked Sendable {
    private let converter: KanaKanjiConverter
    private let options: ConvertRequestOptions

    /// `dictionaryURL` is the converter's `Dictionary` directory;
    /// `workingDirectoryURL` is where it may keep its files
    public init(dictionaryURL: URL, workingDirectoryURL: URL) {
        converter = KanaKanjiConverter(
            dicdataStore: DicdataStore(dictionaryURL: dictionaryURL)
        )
        try? FileManager.default.createDirectory(
            at: workingDirectoryURL,
            withIntermediateDirectories: true
        )
        options = ConvertRequestOptions(
            N_best: 10,
            needTypoCorrection: false,
            requireJapanesePrediction: false,
            requireEnglishPrediction: false,
            keyboardLanguage: .ja_JP,
            learningType: .nothing,
            memoryDirectoryURL: workingDirectoryURL,
            sharedContainerURL: workingDirectoryURL,
            textReplacer: .empty,
            specialCandidateProviders: nil,
            metadata: .init(versionString: "myim")
        )
    }

    /// The input converted so far, so typing on extends it as the
    /// converter expects instead of starting over
    private var composing = ComposingText()
    private var composedElements: [LiveConversionInput.Element] = []

    /// Nil when the letters do not read as kana yet. Hyphens and
    /// punctuation reach the converter as ordinary conversion reads them
    public func convert(romaji: String, limit: Int = 10) -> LiveConversionResult? {
        guard !romaji.isEmpty else {
            reset()
            return nil
        }
        let elements = LiveConversionInput.elements(for: romaji)
        if !elements.starts(with: composedElements) {
            reset()
        }
        for element in elements.dropFirst(composedElements.count) {
            composing.insertAtCursorPosition(
                element.text,
                inputStyle: element.isRomaji ? .roman2kana : .direct
            )
        }
        composedElements = elements
        let reading = composing.convertTarget
        guard !reading.isEmpty else { return nil }
        let results = converter.requestCandidates(composing, options: options)
        return result(
            reading: reading,
            status: LiveConversionInput.reading(reading, elements: elements),
            from: results.mainResults,
            limit: limit
        )
    }

    /// Conversions of kana, as a part being converted again reads
    public func candidates(forReading kana: String, limit: Int = 20) -> [String] {
        guard !kana.isEmpty else { return [] }
        // A separate composition; the typed one is laid out again after it
        reset()
        var direct = ComposingText()
        direct.insertAtCursorPosition(kana, inputStyle: .direct)
        let results = converter.requestCandidates(direct, options: options)
        converter.stopComposition()
        return result(reading: kana, status: .converted, from: results.mainResults, limit: limit)
            .candidates
    }

    /// Only conversions of the whole reading, not of its first part
    private func result(
        reading: String,
        status: LiveConversionInput.Reading,
        from candidates: [KanaKanjiConverterModule.Candidate],
        limit: Int
    ) -> LiveConversionResult {
        var seen = Set<String>()
        let whole = candidates
            .filter { $0.rubyCount == reading.count && seen.insert($0.text).inserted }
            .prefix(limit)
        return LiveConversionResult(
            reading: reading,
            status: status,
            candidates: whole.map(\.text),
            phrases: whole.map { phrases(of: $0, reading: reading) }
        )
    }

    /// The words of a conversion with the kana each reads; one phrase for
    /// all of it where the words do not add up to the reading
    private func phrases(of candidate: KanaKanjiConverterModule.Candidate, reading: String) -> [LiveConversionSegment] {
        let words = candidate.data.map {
            LiveConversionSegment(
                surface: $0.word,
                reading: $0.ruby.applyingTransform(.hiraganaToKatakana, reverse: true) ?? $0.ruby
            )
        }
        guard words.map(\.reading).joined() == reading,
              words.map(\.surface).joined() == candidate.text else {
            return [LiveConversionSegment(surface: candidate.text, reading: reading)]
        }
        // The converter's words are near phrases, as 今日は or いい天気, and
        // the part of speech of a word is that of its start; it numbers
        // particles 147 to 368 and auxiliaries 369 to 554
        return LiveConversionSegment.phrases(
            of: words,
            functionWords: candidate.data.map { (147...554).contains($0.lcid) }
        )
    }

    /// Ends the composition, as after a commit
    public func reset() {
        converter.stopComposition()
        composing = ComposingText()
        composedElements = []
    }
}
