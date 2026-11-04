import Testing
@testable import MyIMECore

@Suite
struct JavaScriptExtensionMetadataTests {
    @Test
    func readsRepeatedMetadataValuesInDefinitionOrder() {
        let source = """
        // @myim-prefix time
        // @myim-prefix 0
        // @myim-prefix 1
        // @myim-prefix 2

        function candidates(context) { return [] }
        """

        #expect(JavaScriptExtensionMetadata.values(
            "myim-prefix",
            in: source
        ) == ["time", "0", "1", "2"])
    }

    @Test
    func ignoresEmptyAndLateMetadata() {
        let lateMetadata = Array(repeating: "// comment", count: 20)
            .joined(separator: "\n") + "\n// @myim-prefix late"

        #expect(JavaScriptExtensionMetadata.values(
            "myim-prefix",
            in: "// @myim-prefix \n"
        ).isEmpty)
        #expect(JavaScriptExtensionMetadata.values(
            "myim-prefix",
            in: lateMetadata
        ).isEmpty)
    }

    @Test
    func matchesAnyDeclaredPrefixAndKeepsEmptyMetadataGlobal() {
        let prefixes = ["time", "0", "1", "2"]

        #expect(JavaScriptExtensionMetadata.matches(
            input: "14:30",
            prefixes: prefixes
        ))
        #expect(JavaScriptExtensionMetadata.matches(
            input: "time",
            prefixes: prefixes
        ))
        #expect(!JavaScriptExtensionMetadata.matches(
            input: "99:99",
            prefixes: prefixes
        ))
        #expect(JavaScriptExtensionMetadata.matches(
            input: "anything",
            prefixes: []
        ))
    }

    /// A script for whole words is not run for every word starting alike
    @Test
    func exactInputsMatchOnlyTheWholeInput() {
        #expect(JavaScriptExtensionMetadata.matches(
            input: "tori",
            prefixes: ["eto"],
            exactInputs: ["tori", "i"]
        ))
        #expect(JavaScriptExtensionMetadata.matches(
            input: "eto2026",
            prefixes: ["eto"],
            exactInputs: ["tori", "i"]
        ))
        #expect(!JavaScriptExtensionMetadata.matches(
            input: "ita",
            prefixes: ["eto"],
            exactInputs: ["tori", "i"]
        ))
        #expect(!JavaScriptExtensionMetadata.matches(
            input: "ita",
            prefixes: [],
            exactInputs: ["i"]
        ))
    }
}
