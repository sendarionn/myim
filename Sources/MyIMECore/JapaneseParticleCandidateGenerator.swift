/// A particle composition and the dictionary candidate it was built on
public struct ParticleComposition: Equatable, Sendable {
    public let text: String
    /// The dictionary candidate before the particle, such as 私 in 私は
    public let base: String
    /// The romaji reading the base candidate was looked up with
    public let baseReading: String

    public init(text: String, base: String, baseReading: String) {
        self.text = text
        self.base = base
        self.baseReading = baseReading
    }
}

public enum JapaneseParticleCandidateGenerator {
    // 選定根拠はdocs/JAPANESE_PARTICLE_SOURCES.mdを参照
    /// Runtime dictionaries do not retain POS data, so connections are
    /// judged from how the candidate is written
    private enum ConnectionRule: Sendable {
        /// Kanji and katakana only, as nouns are written
        case nounLikeByScript
        /// Nouns and na-adjective stems such as 学生 and 便利, and
        /// i-adjectives such as 美しい; verbs end in an u-row kana and kana
        /// words cannot be told apart, so neither is joined
        case copulaStemByScript
    }

    private struct Particle: Sendable {
        let reading: String
        let text: String
        let leadingConnection: ConnectionRule?
        /// The words this ending may follow; nil joins any word
        let trailingConnection: ConnectionRule?
        let minimumStemLength: Int

        init(
            reading: String,
            text: String,
            leadingConnection: ConnectionRule? = nil,
            trailingConnection: ConnectionRule? = nil,
            minimumStemLength: Int = 2
        ) {
            self.reading = reading
            self.text = text
            self.leadingConnection = leadingConnection
            self.trailingConnection = trailingConnection
            self.minimumStemLength = minimumStemLength
        }
    }

    /// Copula and sentence endings that follow a noun or adjective as a
    /// whole input, such as `kouhodearu` 候補である; だ and its forms follow
    /// nouns and na-adjective stems only, since 美しいだ and 美しいでした are
    /// not Japanese
    private static let copulaEndings: [Particle] = [
        Particle(reading: "desu", text: "です", trailingConnection: .copulaStemByScript),
        Particle(reading: "desuka", text: "ですか", trailingConnection: .copulaStemByScript),
        Particle(reading: "desune", text: "ですね", trailingConnection: .copulaStemByScript),
        Particle(reading: "desuyo", text: "ですよ", trailingConnection: .copulaStemByScript),
        Particle(reading: "deshou", text: "でしょう", trailingConnection: .copulaStemByScript),
        Particle(reading: "darou", text: "だろう", trailingConnection: .copulaStemByScript),
        Particle(reading: "kamoshirenai", text: "かもしれない", trailingConnection: .copulaStemByScript),
        Particle(reading: "deshita", text: "でした", trailingConnection: .nounLikeByScript),
        // Short readings ending in da are common words, so だ follows
        // stems of four letters or more, as kouho and benri are
        Particle(
            reading: "da",
            text: "だ",
            trailingConnection: .nounLikeByScript,
            minimumStemLength: 4
        ),
        Particle(reading: "datta", text: "だった", trailingConnection: .nounLikeByScript),
        Particle(reading: "dearu", text: "である", trailingConnection: .nounLikeByScript),
        Particle(reading: "deatta", text: "であった", trailingConnection: .nounLikeByScript),
        Particle(reading: "dehanai", text: "ではない", trailingConnection: .nounLikeByScript),
        Particle(reading: "janai", text: "じゃない", trailingConnection: .nounLikeByScript),
        Particle(reading: "dehanakatta", text: "ではなかった", trailingConnection: .nounLikeByScript),
        Particle(reading: "janakatta", text: "じゃなかった", trailingConnection: .nounLikeByScript),
        Particle(reading: "dehaarimasen", text: "ではありません", trailingConnection: .nounLikeByScript),
        Particle(reading: "dayo", text: "だよ", trailingConnection: .nounLikeByScript),
        Particle(reading: "dayone", text: "だよね", trailingConnection: .nounLikeByScript),
        Particle(reading: "nara", text: "なら", trailingConnection: .nounLikeByScript),
        Particle(reading: "deareba", text: "であれば", trailingConnection: .nounLikeByScript),
        Particle(reading: "dattara", text: "だったら", trailingConnection: .nounLikeByScript),
        Particle(reading: "nohazuda", text: "のはずだ", trailingConnection: .nounLikeByScript),
        Particle(reading: "dasouda", text: "だそうだ", trailingConnection: .nounLikeByScript),
        Particle(reading: "dearubeki", text: "であるべき", trailingConnection: .nounLikeByScript),
        Particle(reading: "dearukamoshirenai", text: "であるかもしれない", trailingConnection: .nounLikeByScript),
    ]

    private static let particles: [Particle] = copulaEndings + [
        Particle(reading: "wotsuujite", text: "を通じて"),
        Particle(reading: "wotooshite", text: "を通して"),
        Particle(reading: "nikurabete", text: "に比べて"),
        Particle(reading: "nikanshite", text: "に関して"),
        Particle(reading: "nitaisite", text: "に対して"),
        Particle(reading: "nitsurete", text: "につれて"),
        Particle(reading: "womegutte", text: "をめぐって"),
        Particle(reading: "nitsuite", text: "について"),
        Particle(reading: "notameni", text: "のために"),
        Particle(reading: "niyotte", text: "によって"),
        Particle(reading: "nioite", text: "において"),
        Particle(reading: "nitotte", text: "にとって"),
        Particle(reading: "toshite", text: "として"),
        Particle(reading: "woukete", text: "を受けて"),
        Particle(reading: "nitsuki", text: "につき"),
        Particle(reading: "niyoru", text: "による"),
        Particle(reading: "notame", text: "のため"),
        Particle(reading: "bakari", text: "ばかり"),
        Particle(reading: "shika", text: "しか"),
        Particle(reading: "gurai", text: "ぐらい"),
        Particle(reading: "kurai", text: "くらい"),
        Particle(reading: "dake", text: "だけ"),
        Particle(reading: "hodo", text: "ほど"),
        Particle(reading: "koso", text: "こそ"),
        Particle(reading: "sae", text: "さえ"),
        Particle(reading: "nite", text: "にて"),
        Particle(reading: "node", text: "ので"),
        Particle(reading: "noni", text: "のに"),
        Particle(reading: "kara", text: "から"),
        Particle(reading: "made", text: "まで"),
        Particle(reading: "yori", text: "より"),
        Particle(reading: "wo", text: "を"),
        Particle(reading: "ni", text: "に"),
        Particle(reading: "ha", text: "は"),
        Particle(reading: "ga", text: "が"),
        Particle(reading: "de", text: "で"),
        Particle(reading: "to", text: "と"),
        Particle(
            reading: "no",
            text: "の",
            leadingConnection: .nounLikeByScript
        ),
        Particle(reading: "mo", text: "も"),
        Particle(reading: "he", text: "へ"),
        Particle(reading: "ya", text: "や"),
        Particle(reading: "ka", text: "か"),
        Particle(reading: "ne", text: "ね"),
        Particle(reading: "yo", text: "よ")
    ]

    public static func candidates(
        for input: String,
        limit: Int = 16,
        exactCandidates: (String) -> [String]
    ) -> [String] {
        compositions(
            for: input,
            limit: limit,
            exactCandidates: exactCandidates
        ).map(\.text)
    }

    public static func compositions(
        for input: String,
        limit: Int = 16,
        exactCandidates: (String) -> [String]
    ) -> [ParticleComposition] {
        guard limit > 0 else { return [] }
        let input = RomajiCanonicalizer.canonicalInput(from: input)
        guard input.count >= 4 else { return [] }

        var results: [ParticleComposition] = []
        var seen = Set<String>()

        func append(stem: String, particle: Particle) {
            guard stem.count >= particle.minimumStemLength else { return }
            for candidate in exactCandidates(stem) where !candidate.isEmpty
                && particle.trailingConnection.map({
                    allowsConnection(candidate, rule: $0)
                }) ?? true {
                let combined = candidate + particle.text
                if seen.insert(combined).inserted {
                    results.append(ParticleComposition(
                        text: combined,
                        base: candidate,
                        baseReading: stem
                    ))
                }
                if results.count >= limit { return }
            }
        }

        func appendLeading(stem: String, particle: Particle) {
            guard stem.count >= 2,
                  let rule = particle.leadingConnection else { return }
            for candidate in exactCandidates(stem)
            where allowsConnection(candidate, rule: rule) {
                let combined = particle.text + candidate
                if seen.insert(combined).inserted {
                    results.append(ParticleComposition(
                        text: combined,
                        base: candidate,
                        baseReading: stem
                    ))
                }
                if results.count >= limit { return }
            }
        }

        let orderedParticles = particles.sorted {
            $0.reading.count > $1.reading.count
        }
        for particle in orderedParticles {
            guard results.count < limit else { break }
            if input.hasSuffix(particle.reading) {
                append(
                    stem: String(input.dropLast(particle.reading.count)),
                    particle: particle
                )
            }
        }
        for particle in orderedParticles where particle.leadingConnection != nil {
            guard results.count < limit else { break }
            if input.hasPrefix(particle.reading) {
                appendLeading(
                    stem: String(input.dropFirst(particle.reading.count)),
                    particle: particle
                )
            }
        }
        return results
    }

    private static func allowsConnection(
        _ candidate: String,
        rule: ConnectionRule
    ) -> Bool {
        guard !candidate.isEmpty else { return false }
        let nounLike = candidate.allSatisfy {
            isKanji($0) || isKatakana($0)
        }
        switch rule {
        case .nounLikeByScript:
            return nounLike
        case .copulaStemByScript:
            return nounLike || isIAdjectiveLike(candidate)
        }
    }

    /// Written with a kanji stem and kana inflection ending in い, as 美しい
    /// and 高い are; a verb never ends in い
    private static func isIAdjectiveLike(_ candidate: String) -> Bool {
        guard candidate.last == "い",
              let first = candidate.first, isKanji(first) else {
            return false
        }
        return candidate.dropFirst().allSatisfy {
            isKanji($0) || isHiragana($0)
        }
    }

    private static func isHiragana(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy {
            (0x3041...0x309f).contains($0.value)
        }
    }

    private static func isKanji(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy {
            (0x3400...0x4dbf).contains($0.value)
                || (0x4e00...0x9fff).contains($0.value)
                || (0xf900...0xfaff).contains($0.value)
                || (0x20000...0x2fa1f).contains($0.value)
        }
    }

    private static func isKatakana(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy {
            (0x30a1...0x30fa).contains($0.value)
                || (0x30fd...0x30ff).contains($0.value)
                || (0x31f0...0x31ff).contains($0.value)
                || (0xff66...0xff9d).contains($0.value)
                || $0.value == 0x30fc
        }
    }

    public static func generatedOnlyCandidates(
        generated: [String],
        exactDictionaryCandidates: [String]
    ) -> Set<String> {
        Set(generated).subtracting(exactDictionaryCandidates)
    }
}
