import Testing
@testable import MyIMECore

struct GenerationPromptBuilderTests {
    @Test func acceptsEitherField() {
        #expect(GenerationPromptBuilder.prompt(requirements: "支払いの催促", purpose: "") != nil)
        #expect(GenerationPromptBuilder.prompt(requirements: "", purpose: "柔らかく伝える") != nil)
    }

    @Test func rejectsEmptyForm() {
        #expect(GenerationPromptBuilder.prompt(requirements: " \n", purpose: "") == nil)
    }

    @Test func requestsBodyOnlyWithoutInventingFacts() {
        let prompt = GenerationPromptBuilder.prompt(
            requirements: "支払いの催促",
            purpose: "柔らかく、早めの支払いを依頼"
        )
        #expect(prompt?.contains("完成した本文だけ") == true)
        #expect(prompt?.contains("事実は創作しない") == true)
    }

    @Test func removesWholeTextWrappers() {
        #expect(GenerationPromptBuilder.normalizeGeneratedText("「本文です」") == "本文です")
        #expect(GenerationPromptBuilder.normalizeGeneratedText("（「本文です」）") == "本文です")
        #expect(GenerationPromptBuilder.normalizeGeneratedText("文中の「括弧」は残す") == "文中の「括弧」は残す")
    }
}
