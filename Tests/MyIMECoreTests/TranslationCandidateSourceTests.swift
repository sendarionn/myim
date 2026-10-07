import Testing
@testable import MyIMECore

@Suite
struct TranslationCandidateSourceTests {
    @Test @MainActor
    func returnsOneGroupPerLanguageInSettingOrder() async throws {
        let source = TranslationCandidateSource(
            targetIdentifiers: ["en", "zh-Hans"]
        )

        let groups = try await source.groups(for: "愛") { _, target in
            target == "en" ? "love / affection" : "爱 / 爱情"
        }

        #expect(groups.map(\.targetIdentifier) == ["en", "zh-Hans"])
        #expect(groups[0].candidates.map(\.storageText)
            == ["love", "affection"])
        #expect(groups[1].candidates.map(\.storageText) == ["爱", "爱情"])
    }

    @Test @MainActor
    func keepsTheSameTranslationInEveryLanguage() async throws {
        let source = TranslationCandidateSource(
            targetIdentifiers: ["en", "fr"]
        )

        let groups = try await source.groups(for: "テスト") { _, _ in
            "test / test"
        }

        #expect(groups.map { $0.candidates.map(\.storageText) }
            == [["test"], ["test"]])
    }

    @Test @MainActor
    func completionOrderDoesNotChangeTheGroupOrder() async throws {
        let source = TranslationCandidateSource(
            targetIdentifiers: ["en", "zh-Hans", "ko"]
        )

        let groups = try await source.groups(for: "愛") { _, target in
            // Later languages answer sooner
            let delay: UInt64 = switch target {
            case "en": 3_000_000
            case "zh-Hans": 2_000_000
            default: 1_000_000
            }
            try? await Task.sleep(nanoseconds: delay)
            return target == "en" ? "love" : target == "ko" ? "사랑" : "爱"
        }

        #expect(groups.map(\.targetIdentifier) == ["en", "zh-Hans", "ko"])
    }

    @Test @MainActor
    func createsStructuredTranslationCandidates() async throws {
        let source = TranslationCandidateSource(targetIdentifiers: ["en"])

        let groups = try await source.groups(for: "候補") { _, _ in
            "Candidate"
        }

        let candidates = groups.flatMap(\.candidates)
        #expect(candidates.count == 1)
        #expect(candidates[0].storageText == "candidate")
        #expect(candidates[0].hasSource(.translation))
        #expect(candidates[0].hasAttribute(.generated))
        #expect(candidates[0].origins.first?.reading == "候補")
    }

    @Test @MainActor
    func skipsUnavailableTargetsAndTheUnchangedInput() async throws {
        let source = TranslationCandidateSource(
            targetIdentifiers: ["en", "fr"]
        )

        let groups = try await source.groups(for: "候補") {
            input, target in
            target == "en" ? nil : input
        }

        #expect(groups.isEmpty)
    }

    @Test
    func panelsFollowTheGroupsWithLanguageNames() {
        let groups = ["en", "zh-Hans", "ko"].map {
            TranslationCandidateGroup(
                targetIdentifier: $0,
                candidates: [Candidate(storageText: $0, source: .translation)]
            )
        }

        let panels = TranslationPanelContent.panels(for: groups)

        #expect(panels.map(\.caption) == ["英語", "中国語（簡体字）", "韓国語"])
        #expect(panels.map(\.candidates) == [["en"], ["zh-Hans"], ["ko"]])
    }

    @Test
    func panelCountMatchesTheLanguagesWithResults() {
        for count in 1...3 {
            let groups = TranslationTargetLanguage.available.prefix(count).map {
                TranslationCandidateGroup(
                    targetIdentifier: $0.identifier,
                    candidates: [Candidate(storageText: "a", source: .translation)]
                )
            }
            #expect(TranslationPanelContent.panels(for: groups).count == count)
        }
    }
}
