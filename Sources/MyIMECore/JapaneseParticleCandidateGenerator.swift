public enum JapaneseParticleCandidateGenerator {
    // 選定根拠はdocs/JAPANESE_PARTICLE_SOURCES.mdを参照
    private enum LeadingConnectionRule: Sendable {
        /// Runtime dictionaries do not retain POS data, so this accepts
        /// candidates written only with kanji and katakana as noun-like
        case nounLikeByScript
    }

    private struct Particle: Sendable {
        let reading: String
        let text: String
        let leadingConnection: LeadingConnectionRule?

        init(
            reading: String,
            text: String,
            leadingConnection: LeadingConnectionRule? = nil
        ) {
            self.reading = reading
            self.text = text
            self.leadingConnection = leadingConnection
        }
    }

    private static let particles: [Particle] = [
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
        guard limit > 0 else { return [] }
        let input = RomajiCanonicalizer.canonicalInput(from: input)
        guard input.count >= 4 else { return [] }

        var results: [String] = []
        var seen = Set<String>()

        func append(stem: String, particle: Particle) {
            guard stem.count >= 2 else { return }
            for candidate in exactCandidates(stem) where !candidate.isEmpty {
                let combined = candidate + particle.text
                if seen.insert(combined).inserted {
                    results.append(combined)
                }
                if results.count >= limit { return }
            }
        }

        func appendLeading(stem: String, particle: Particle) {
            guard stem.count >= 2,
                  let rule = particle.leadingConnection else { return }
            for candidate in exactCandidates(stem)
            where allowsLeadingConnection(candidate, rule: rule) {
                let combined = particle.text + candidate
                if seen.insert(combined).inserted {
                    results.append(combined)
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

    private static func allowsLeadingConnection(
        _ candidate: String,
        rule: LeadingConnectionRule
    ) -> Bool {
        guard !candidate.isEmpty else { return false }
        switch rule {
        case .nounLikeByScript:
            return candidate.allSatisfy {
                isKanji($0) || isKatakana($0)
            }
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
