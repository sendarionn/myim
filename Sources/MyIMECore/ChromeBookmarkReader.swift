import Foundation

public struct ChromeBookmarkReader: Sendable {
    public init() {}

    public func bookmarks(in userDataDirectory: URL) throws -> [BrowserBookmark] {
        let fileManager = FileManager.default
        let profileNames = profileNames(in: userDataDirectory)
        let profileDirectories = try fileManager.contentsOfDirectory(
            at: userDataDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }

        var result: [BrowserBookmark] = []
        var seen = Set<BrowserBookmark>()
        for profileDirectory in profileDirectories.sorted(by: {
            $0.lastPathComponent < $1.lastPathComponent
        }) {
            let profileKey = profileDirectory.lastPathComponent
            let profile = profileNames[profileKey] ?? profileKey
            for fileName in ["Bookmarks", "AccountBookmarks"] {
                let file = profileDirectory.appendingPathComponent(fileName)
                guard fileManager.fileExists(atPath: file.path) else { continue }
                guard let data = try? Data(contentsOf: file, options: [.mappedIfSafe]),
                      let root = try? JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                      let roots = root["roots"] as? [String: Any] else {
                    continue
                }
                for key in roots.keys.sorted() {
                    guard let node = roots[key] as? [String: Any] else { continue }
                    appendBookmarks(
                        from: node,
                        folderComponents: [],
                        profile: profile,
                        result: &result,
                        seen: &seen
                    )
                }
            }
        }
        return result
    }

    private func profileNames(in directory: URL) -> [String: String] {
        let localState = directory.appendingPathComponent("Local State")
        guard let data = try? Data(contentsOf: localState, options: [.mappedIfSafe]),
              let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
              let profile = root["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: Any] else {
            return [:]
        }
        return infoCache.reduce(into: [:]) { result, item in
            guard let info = item.value as? [String: Any],
                  let name = info["name"] as? String,
                  !name.isEmpty else { return }
            result[item.key] = name
        }
    }

    private func appendBookmarks(
        from node: [String: Any],
        folderComponents: [String],
        profile: String,
        result: inout [BrowserBookmark],
        seen: inout Set<BrowserBookmark>
    ) {
        if let url = node["url"] as? String, !url.isEmpty {
            let bookmark = BrowserBookmark(
                title: node["name"] as? String ?? "",
                url: url,
                folderPath: folderComponents.joined(separator: " / "),
                profile: profile
            )
            if seen.insert(bookmark).inserted {
                result.append(bookmark)
            }
            return
        }

        var nextComponents = folderComponents
        if let name = node["name"] as? String, !name.isEmpty {
            nextComponents.append(name)
        }
        guard let children = node["children"] as? [[String: Any]] else { return }
        for child in children {
            appendBookmarks(
                from: child,
                folderComponents: nextComponents,
                profile: profile,
                result: &result,
                seen: &seen
            )
        }
    }
}
