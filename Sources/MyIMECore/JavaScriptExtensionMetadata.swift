import Foundation

public enum JavaScriptExtensionMetadata {
    public static func values(_ name: String, in source: String) -> [String] {
        let marker = "// @\(name) "
        return source.split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(20)
            .compactMap { line -> String? in
                let text = String(line)
                guard text.hasPrefix(marker) else { return nil }
                let value = String(text.dropFirst(marker.count))
                    .trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
    }

    /// A script without either declaration runs for every input
    public static func matches(
        input: String,
        prefixes: [String],
        exactInputs: [String] = []
    ) -> Bool {
        (prefixes.isEmpty && exactInputs.isEmpty)
            || prefixes.contains(where: input.hasPrefix)
            || exactInputs.contains(input)
    }
}
