import Foundation
import KanaKanjiConverterModule
import MyIMECore

/// The result of converting a whole composition at once
public struct LiveConversionResult: Equatable, Sendable {
    /// The kana the typed letters read as
    public let reading: String
    /// Conversions of the reading after the fixed phrases (the whole of it
    /// without any), best first
    public let candidates: [String]
    /// The best of them in phrases, each with the kana it reads
    public let phrases: [LiveConversionSegment]
}

/// The experimental live conversion: the whole composition converted as
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
    /// punctuation reach the converter as ordinary conversion reads them.
    /// With `fixedReading`, the kana phrases corrected by hand read, only
    /// the reading after it is converted
    public func convert(
        romaji: String,
        fixedReading: String = "",
        limit: Int = 10
    ) -> LiveConversionResult? {
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
        if !fixedReading.isEmpty, reading.hasPrefix(fixedReading) {
            let rest = String(reading.dropFirst(fixedReading.count))
            let converted = convert(kana: rest, limit: limit)
            return LiveConversionResult(
                reading: reading,
                candidates: converted.candidates,
                phrases: converted.phrases
            )
        }
        let results = converter.requestCandidates(composing, options: options)
        return result(reading: reading, from: results.mainResults, limit: limit)
    }

    /// Conversions of kana, as a phrase being corrected reads
    public func candidates(forReading kana: String, limit: Int = 20) -> [String] {
        convert(kana: kana, limit: limit).candidates
    }

    private func convert(kana: String, limit: Int) -> (candidates: [String], phrases: [LiveConversionSegment]) {
        guard !kana.isEmpty else { return ([""], []) }
        // A separate composition; the typed one is laid out again after it
        converter.stopComposition()
        composing = ComposingText()
        composedElements = []
        var direct = ComposingText()
        direct.insertAtCursorPosition(kana, inputStyle: .direct)
        let results = converter.requestCandidates(direct, options: options)
        converter.stopComposition()
        let converted = result(reading: kana, from: results.mainResults, limit: limit)
        return (converted.candidates, converted.phrases)
    }

    /// Only conversions of the whole reading, not of its first part
    private func result(
        reading: String,
        from candidates: [KanaKanjiConverterModule.Candidate],
        limit: Int
    ) -> LiveConversionResult {
        let whole = candidates.filter { $0.rubyCount == reading.count }
        var seen = Set<String>()
        let texts = whole.map(\.text).filter { seen.insert($0).inserted }
        return LiveConversionResult(
            reading: reading,
            candidates: Array(texts.prefix(limit)),
            phrases: whole.first.map { phrases(of: $0, reading: reading) } ?? []
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
        guard words.map(\.reading).joined() == reading else {
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
