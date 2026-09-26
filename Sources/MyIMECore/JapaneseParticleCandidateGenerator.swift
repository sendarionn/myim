public enum JapaneseParticleCandidateGenerator {
    // 選定根拠はdocs/JAPANESE_PARTICLE_SOURCES.mdを参照
    private struct Particle: Sendable {
        let reading: String
        let text: String
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
        Particle(reading: "no", text: "の"),
        Particle(reading: "mo", text: "も"),
        Particle(reading: "he", text: "へ"),
        Particle(reading: "ya", text: "や"),
        Particle(reading: "ka", text: "か"),
        Particle(reading: "ne", text: "ね"),
        Particle(reading: "yo", text: "よ"),
        Particle(reading: "te", text: "て")
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
        return results
    }

    public static func generatedOnlyCandidates(
        generated: [String],
        exactDictionaryCandidates: [String]
    ) -> Set<String> {
        Set(generated).subtracting(exactDictionaryCandidates)
    }
}
