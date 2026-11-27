@preconcurrency import AppKit
import MyIMECore

/// Where the input method's data comes from and goes: the bundled
/// dictionaries, the user dictionary, and the learning histories read at
/// launch with the writers that save them
enum InputMethodData {
    /// Large histories are written once typing pauses
    static let largeHistoryWriteDelay: TimeInterval = 5

    static func loadBasicEntries() -> [DictionaryEntry] {
        guard
            let dictionaryURL = inputMethodResourceURL(
                forResource: "basic-dictionary",
                withExtension: "tsv"
            ),
            let dictionaryText = try? String(
                contentsOf: dictionaryURL,
                encoding: .utf8
            ),
            let entries = try? DictionaryParser().parse(dictionaryText)
        else {
            return []
        }
        if let cache = try? basicDictionaryCache(),
           let cachedEntries = loadEntries(from: cache) {
            return addingBundledRequiredEntries(
                to: cachedEntries,
                bundledEntries: entries
            )
        }
        return entries
    }

    static func loadBundledEntries(resource: String) -> [DictionaryEntry] {
        guard let text = loadBundledText(resource: resource),
              let entries = try? DictionaryParser().parse(text) else {
            return []
        }
        return entries
    }

    static func addingBundledRequiredEntries(
        to entries: [DictionaryEntry],
        bundledEntries: [DictionaryEntry]? = nil
    ) -> [DictionaryEntry] {
        let bundled = bundledEntries ?? {
            guard let text = loadBundledText(resource: "basic-dictionary"),
                  let parsed = try? DictionaryParser().parse(text) else {
                return []
            }
            return parsed
        }()
        let readings: Set<String> = [
            "opushon", "kontorooru", "shifuto", "supeesu", "ritaan",
            "komando", "kyappusurokku", "esukeepu", "entaa", "tabu",
            "deriito", "fowaadoderiito", "bakkusupeesu", "ijekuto",
            "command", "cmd", "option", "alt", "shift", "control",
            "ctrl", "capslock", "escape", "esc", "return", "enter",
            "tab", "delete", "forwarddelete", "backspace", "space",
            "eject", "yajirushi", "migiyajirushi", "hidariyajirushi",
            "ueyajirushi", "shitayajirushi", "maru", "sankaku",
            "migisankaku", "hidarisankaku", "uesankaku",
            "shitasankaku", "shikaku", "hoshi", "puramain", "kakeru",
            "waru", "nottoikooru", "yakunari", "shounari", "dainari",
            "mugen", "ruuto", "shiguma", "sekibun", "komejirushi",
            "asutarisuku", "dagaa", "daburudagaa", "onpu", "furatto",
            "shaapu", "supe-do", "kurabu", "haato", "daiya", "en",
            "doru", "yuuro", "pondo", "sento", "won", "yuubin",
            "sesshi", "kashi", "nambaa", "tore-domaaku",
            "kopiiraito", "touroku", "nakaguro"
        ]
        return entries + bundled.filter { readings.contains($0.input) }
    }

    static func loadBundledText(resource: String) -> String? {
        guard let url = inputMethodResourceURL(
            forResource: resource,
            withExtension: "tsv"
        ) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func loadMozcDictionaryEngine() -> IndexedDictionaryEngine {
        guard
            let dictionaryURL = inputMethodResourceURL(
                forResource: "mozc-dictionary",
                withExtension: "tsv"
            ),
            let engine = try? IndexedDictionaryEngine(contentsOf: dictionaryURL)
        else {
            return IndexedDictionaryEngine()
        }
        return engine
    }

    static func loadUserEntries() -> [DictionaryEntry] {
        guard let cache = try? userDictionaryCache() else {
            return []
        }
        return loadEntries(from: cache) ?? []
    }

    static var importedDictionaryStore: ImportedDictionaryStore {
        ImportedDictionaryStore(
            directoryURL: userDataURL(fileName: "imported-dictionaries")
        )
    }

    static func bundledBasicDictionaryRevision() -> String? {
        guard
            let metadataURL = inputMethodResourceURL(
                forResource: "basic-dictionary-source",
                withExtension: "json"
            ),
            let data = try? Data(contentsOf: metadataURL),
            let metadata = try? JSONDecoder().decode(
                BundledBasicDictionaryMetadata.self,
                from: data
            )
        else {
            return nil
        }

        return metadata.generated
    }

    static func inputMethodResourceURL(
        forResource name: String,
        withExtension fileExtension: String
    ) -> URL? {
        let bundleIdentifier = "io.github.sendarionn.inputmethod.myime"
        var bundles: [Bundle] = []
        if let identifierBundle = Bundle(identifier: bundleIdentifier) {
            bundles.append(identifierBundle)
        }
        bundles.append(Bundle(for: InputController.self))

        let executableURL = URL(
            fileURLWithPath: CommandLine.arguments.first ?? ""
        )
        let executableBundleURL = executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        if let executableBundle = Bundle(url: executableBundleURL) {
            bundles.append(executableBundle)
        }

        let installedBundleURLs = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(
                    "Library/Input Methods/myim.app",
                    isDirectory: true
                ),
            URL(
                fileURLWithPath: "/Library/Input Methods/myim.app",
                isDirectory: true
            )
        ]
        bundles.append(
            contentsOf: installedBundleURLs.compactMap(Bundle.init(url:))
        )

        for bundle in bundles {
            if let url = bundle.url(
                forResource: name,
                withExtension: fileExtension
            ) {
                return url
            }
        }

        NSLog("myimのリソースが見つかりません: %@.%@", name, fileExtension)
        return nil
    }

    /// The entries saved, rewritten in the current format when the file is
    /// in an older one; nil when the file cannot be read
    static func loadEntries(
        from cache: DictionaryCache
    ) -> [DictionaryEntry]? {
        guard cache.containsDictionary(),
              let readableURL = cache.readableDictionaryURL(),
              let dictionaryText = try? String(contentsOf: readableURL, encoding: .utf8),
              let entries = try? DictionaryParser().parse(dictionaryText)
        else {
            return nil
        }
        let tsv = DictionarySerializer.text(from: entries)
        if readableURL != cache.dictionaryURL || dictionaryText != tsv {
            let metadata = (try? cache.loadMetadata()) ?? nil
            try? cache.save(
                dictionaryText: tsv,
                metadata: metadata ?? DictionaryCacheMetadata(
                    syncedAt: Date(),
                    entryCount: entries.count
                )
            )
        }
        return entries
    }

    static func basicDictionaryCache() throws -> DictionaryCache {
        let applicationCache = try DictionaryCache.applicationSupport()
        return DictionaryCache(
            directoryURL: applicationCache.directoryURL
                .appendingPathComponent("basic", isDirectory: true)
        )
    }

    static func userDictionaryCache() throws -> DictionaryCache {
        try DictionaryCache.userDictionary()
    }

    static func loadCandidateSelectionHistory()
        -> CandidateSelectionHistory {
        loadUserData(
            from: candidateSelectionHistoryURL(),
            empty: CandidateSelectionHistory()
        ) { data in
            if let history = try? JSONDecoder().decode(
                CandidateSelectionHistory.self,
                from: data
            ) {
                return history
            }
            return (try? JSONDecoder().decode([String: Int].self, from: data))
                .map { CandidateSelectionHistory(ranks: $0) }
        }
    }

    /// A file that cannot be read starts empty only after it is copied
    /// aside, as the next save replaces it
    static func loadUserData<Value>(
        from url: URL,
        empty: @autoclosure () -> Value,
        decode: (Data) -> Value?
    ) -> Value {
        switch PersistedFile.load(from: url, decode: decode) {
        case .missing:
            return empty()
        case let .loaded(value):
            return value
        case let .unreadable(preservedAt):
            NSLog(
                "ユーザーデータを読み込めないため空の状態で開始: %@ 退避先: %@",
                url.lastPathComponent,
                preservedAt?.lastPathComponent ?? "退避失敗"
            )
            return empty()
        }
    }

    static func makeCandidateSelectionHistoryStore()
        -> CandidateSelectionHistoryStore {
        let historyURL = candidateSelectionHistoryURL()
        if FileManager.default.fileExists(atPath: historyURL.path) {
            let protectedEntries = Set(loadUserEntries().flatMap { entry in
                entry.candidates.map {
                    DynamicDateTimeHistoryMigration.ProtectedEntry(
                        reading: entry.reading,
                        candidate: DictionaryCandidateRepresentation.value(
                            from: $0
                        )
                    )
                }
            })
            do {
                if let report = try DynamicDateTimeHistoryMigrationRunner
                    .migrateIfNeeded(
                        historyURL: historyURL,
                        backupURL: userDataURL(
                            fileName: "candidate-selection-history.dynamic-date-migration-v2.backup.json"
                        ),
                        markerURL: userDataURL(
                            fileName: "dynamic-date-history-migration-v2.json"
                        ),
                        legacySourceURL: userDataURL(
                            fileName: "candidate-selection-history.dynamic-date-migration-v1.backup.json"
                        ),
                        protecting: protectedEntries
                    ) {
                    NSLog(
                        "動的日時履歴の移行: removed=%d candidates=%d preferences=%d protected=%d unclassified=%d",
                        report.removedAssociationCount,
                        report.removedCandidateCount,
                        report.migratedPreferenceCount,
                        report.retainedProtectedCount,
                        report.unclassifiedAssociationCount
                    )
                }
            } catch {
                NSLog(
                    "動的日時履歴の移行に失敗: %@",
                    error.localizedDescription
                )
            }
        }
        return CandidateSelectionHistoryStore(
            history: loadCandidateSelectionHistory(),
            writer: DeferredJSONFileWriter(
                fileURL: historyURL,
                delay: largeHistoryWriteDelay,
                queueLabel: "myim.candidate-selection-history",
                errorHandler: {
                    NSLog(
                        "候補選択履歴の保存に失敗: %@",
                        $0.localizedDescription
                    )
                }
            )
        )
    }

    static func candidateSelectionHistoryURL() -> URL {
        userDataURL(fileName: "candidate-selection-history.json")
    }

    static func loadUnselectedInputLearningHistory()
        -> UnselectedInputLearningHistory {
        loadUserData(
            from: unselectedInputLearningHistoryURL(),
            empty: UnselectedInputLearningHistory()
        ) {
            try? JSONDecoder().decode(UnselectedInputLearningHistory.self, from: $0)
        }
    }

    static func loadDerivedCandidateExclusions() -> DerivedCandidateExclusions {
        loadUserData(
            from: derivedCandidateExclusionsURL(),
            empty: DerivedCandidateExclusions()
        ) {
            try? JSONDecoder().decode(DerivedCandidateExclusions.self, from: $0)
        }
    }

    static func saveDerivedCandidateExclusions(_ exclusions: DerivedCandidateExclusions) throws {
        let url = derivedCandidateExclusionsURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(exclusions).write(to: url, options: .atomic)
    }

    static func derivedCandidateExclusionsURL() -> URL {
        userDataURL(fileName: "derived-candidate-exclusions.json")
    }

    static func unselectedInputLearningHistoryURL() -> URL {
        userDataURL(fileName: "unselected-input-learning.json")
    }

    static func loadNextInputPredictionModel()
        -> NextInputPredictionModel {
        var model = loadUserData(
            from: nextInputPredictionModelURL(),
            empty: NextInputPredictionModel()
        ) {
            try? JSONDecoder().decode(NextInputPredictionModel.self, from: $0)
        }
        model.breakSequence()
        return model
    }

    static func nextInputPredictionModelURL() -> URL {
        userDataURL(fileName: "next-input-model.json")
    }

    static func userDataURL(fileName: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/myim/user",
                isDirectory: true
            )
            .appendingPathComponent(fileName)
    }
}

private struct BundledBasicDictionaryMetadata: Decodable {
    let generated: String
}
