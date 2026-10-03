import Foundation

public enum BasicDictionaryStatus: Equatable, Sendable {
    case unchecked
    case loadFailed
    case loaded(basicReadingCount: Int, mozcReadingCount: Int)
    case checking
    case checked(readingCount: Int)
    case latest(readingCount: Int)
    case updated(readingCount: Int)
    case checkFailed

    public var isChecking: Bool {
        self == .checking
    }

    public var description: String {
        switch self {
        case .unchecked:
            return "未確認"
        case .loadFailed:
            return "読込失敗"
        case let .loaded(basicReadingCount, mozcReadingCount):
            return "読込済み（TKGJE \(basicReadingCount)＋Mozc \(mozcReadingCount)input）"
        case .checking:
            return "確認中"
        case let .checked(readingCount):
            return "確認済み（\(readingCount)読み）"
        case let .latest(readingCount):
            return "最新版（\(readingCount)読み）"
        case let .updated(readingCount):
            return "更新完了（\(readingCount)読み）"
        case .checkFailed:
            return "確認失敗"
        }
    }
}

public enum BasicDictionaryUpdateResult: Equatable, Sendable {
    case alreadyLatest(TKGDictionarySnapshot)
    case updated(TKGDictionarySnapshot)
}

public struct BasicDictionaryUpdater: Sendable {
    private let cache: DictionaryCache
    private let bundledRevision: String?

    public init(cache: DictionaryCache, bundledRevision: String?) {
        self.cache = cache
        self.bundledRevision = bundledRevision
    }

    public func apply(
        _ snapshot: TKGDictionarySnapshot,
        syncedAt: Date
    ) throws -> BasicDictionaryUpdateResult {
        let currentRevision = try cache.loadMetadata()?.sourceRevision
            ?? bundledRevision
        guard currentRevision.map({ snapshot.generatedAt > $0 }) ?? true else {
            return .alreadyLatest(snapshot)
        }
        try cache.save(
            dictionaryText: snapshot.dictionaryText,
            metadata: DictionaryCacheMetadata(
                syncedAt: syncedAt,
                entryCount: snapshot.entries.count,
                sourceRevision: snapshot.generatedAt,
                sourceEntryCount: snapshot.sourceEntryCount
            )
        )
        return .updated(snapshot)
    }
}
