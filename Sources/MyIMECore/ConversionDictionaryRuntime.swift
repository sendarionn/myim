public struct ImportedDictionaryRuntime: Sendable {
    public let dictionaries: [ImportedDictionary]
    private let conversionEngines: [String: ConversionEngine]
    private let continuationGenerators:
        [String: DictionaryContinuationCandidateGenerator]

    public init(dictionaries: [ImportedDictionary]) {
        self.dictionaries = dictionaries
        conversionEngines = Dictionary(uniqueKeysWithValues: dictionaries.map {
            ($0.fileURL.lastPathComponent, ConversionEngine(entries: $0.entries))
        })
        continuationGenerators = Dictionary(
            uniqueKeysWithValues: dictionaries.map {
                (
                    $0.fileURL.lastPathComponent,
                    DictionaryContinuationCandidateGenerator(entries: $0.entries)
                )
            }
        )
    }

    public var filenames: [String] {
        dictionaries.map(\.fileURL.lastPathComponent)
    }

    func enabledFilenames(excluding disabled: Set<String>) -> [String] {
        filenames.filter { !disabled.contains($0) }
    }

    func conversionEngines(for filenames: [String]) -> [ConversionEngine] {
        filenames.compactMap { conversionEngines[$0] }
    }

    func continuationGenerators(
        for filenames: [String]
    ) -> [DictionaryContinuationCandidateGenerator] {
        filenames.compactMap { continuationGenerators[$0] }
    }
}

public struct ConversionDictionaryRuntime: Sendable {
    public private(set) var imported: ImportedDictionaryRuntime
    public private(set) var basicEntries: [DictionaryEntry]
    public private(set) var userEngine: LayeredConversionEngine
    /// The user's own dictionary without imported dictionaries
    public private(set) var userDictionaryEngine: LayeredConversionEngine
    /// Enabled imported dictionaries without the user's own dictionary
    public private(set) var importedEngine: LayeredConversionEngine
    public private(set) var basicEngine: ConversionEngine
    public let systemEngine: IndexedDictionaryEngine
    public private(set) var verbInflectionGenerator: VerbInflectionCandidateGenerator
    public let compoundGenerator: CompoundDictionaryCandidateGenerator
    private var userContinuationGenerator:
        LayeredDictionaryContinuationCandidateGenerator
    private var basicContinuationGenerator:
        DictionaryContinuationCandidateGenerator

    public init(
        userEntries: [DictionaryEntry],
        imported: ImportedDictionaryRuntime,
        disabledImportedFilenames: Set<String>,
        basicEntries: [DictionaryEntry],
        basicEngine: ConversionEngine,
        verbInflectionGenerator: VerbInflectionCandidateGenerator,
        compoundGenerator: CompoundDictionaryCandidateGenerator,
        systemEngine: IndexedDictionaryEngine
    ) {
        self.imported = imported
        self.basicEntries = basicEntries
        self.basicEngine = basicEngine
        self.systemEngine = systemEngine
        self.verbInflectionGenerator = verbInflectionGenerator
        self.compoundGenerator = compoundGenerator
        basicContinuationGenerator = DictionaryContinuationCandidateGenerator(
            entries: basicEntries
        )
        (userEngine, userDictionaryEngine, importedEngine, userContinuationGenerator) =
            Self.userLayers(
                userEntries: userEntries,
                imported: imported,
                disabledImportedFilenames: disabledImportedFilenames
            )
    }

    public func enabledImportedFilenames(
        excluding disabled: Set<String>
    ) -> [String] {
        imported.enabledFilenames(excluding: disabled)
    }

    public mutating func rebuildUserLayers(
        userEntries: [DictionaryEntry],
        disabledImportedFilenames: Set<String>
    ) {
        (userEngine, userDictionaryEngine, importedEngine, userContinuationGenerator) =
            Self.userLayers(
                userEntries: userEntries,
                imported: imported,
                disabledImportedFilenames: disabledImportedFilenames
            )
    }

    public mutating func replaceImported(
        _ imported: ImportedDictionaryRuntime,
        userEntries: [DictionaryEntry],
        disabledImportedFilenames: Set<String>
    ) {
        self.imported = imported
        rebuildUserLayers(
            userEntries: userEntries,
            disabledImportedFilenames: disabledImportedFilenames
        )
    }

    public mutating func replaceBasicEntries(_ entries: [DictionaryEntry]) {
        basicEntries = entries
        basicEngine = ConversionEngine(entries: entries)
        basicContinuationGenerator = DictionaryContinuationCandidateGenerator(
            entries: entries
        )
        verbInflectionGenerator = VerbInflectionCandidateGenerator(
            entries: entries
        )
    }

    public func readings(for candidate: String) -> [String] {
        var seen = Set<String>()
        return (userEngine.readings(for: candidate)
            + basicEngine.readings(for: candidate)
            + systemEngine.readings(for: candidate))
            .filter { seen.insert($0).inserted }
    }

    public func continuationCandidates(
        after committedValue: String,
        limit: Int
    ) -> [String] {
        NextInputCandidateMerger.merged(
            preferred: userContinuationGenerator.candidates(
                after: committedValue
            ),
            learned: basicContinuationGenerator.candidates(
                after: committedValue
            ),
            limit: limit
        )
    }

    private static func userLayers(
        userEntries: [DictionaryEntry],
        imported: ImportedDictionaryRuntime,
        disabledImportedFilenames: Set<String>
    ) -> (
        LayeredConversionEngine,
        LayeredConversionEngine,
        LayeredConversionEngine,
        LayeredDictionaryContinuationCandidateGenerator
    ) {
        let enabled = imported.enabledFilenames(
            excluding: disabledImportedFilenames
        )
        let userDictionary = ConversionEngine(entries: userEntries)
        let importedEngines = imported.conversionEngines(for: enabled)
        return (
            LayeredConversionEngine(engines: [userDictionary] + importedEngines),
            LayeredConversionEngine(engines: [userDictionary]),
            LayeredConversionEngine(engines: importedEngines),
            LayeredDictionaryContinuationCandidateGenerator(
                generators: [DictionaryContinuationCandidateGenerator(
                    entries: userEntries
                )] + imported.continuationGenerators(for: enabled)
            )
        )
    }
}
