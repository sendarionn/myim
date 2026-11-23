import Foundation
import KanaKanjiConverterModule

/// The result of converting a whole composition at once
public struct LiveConversionResult: Equatable, Sendable {
    /// The kana the typed letters read as
    public let reading: String
    /// Conversions of the whole reading, best first
    public let candidates: [String]
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

    /// The letters converted so far, so typing on extends them as the
    /// converter expects instead of starting over
    private var composing = ComposingText()
    private var composedRomaji = ""

    /// Nil when the letters do not read as kana yet
    public func convert(romaji: String, limit: Int = 10) -> LiveConversionResult? {
        guard !romaji.isEmpty else {
            reset()
            return nil
        }
        if romaji.hasPrefix(composedRomaji) {
            for letter in romaji.dropFirst(composedRomaji.count) {
                composing.insertAtCursorPosition(String(letter), inputStyle: .roman2kana)
            }
        } else {
            reset()
            for letter in romaji {
                composing.insertAtCursorPosition(String(letter), inputStyle: .roman2kana)
            }
        }
        composedRomaji = romaji
        let reading = composing.convertTarget
        guard !reading.isEmpty else { return nil }
        let results = converter.requestCandidates(composing, options: options)
        var seen = Set<String>()
        let whole = results.mainResults
            .filter { $0.rubyCount == reading.count }
            .map(\.text)
            .filter { seen.insert($0).inserted }
        return LiveConversionResult(reading: reading, candidates: Array(whole.prefix(limit)))
    }

    /// Ends the composition, as after a commit
    public func reset() {
        converter.stopComposition()
        composing = ComposingText()
        composedRomaji = ""
    }
}
