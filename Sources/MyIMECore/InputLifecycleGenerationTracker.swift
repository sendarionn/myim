public struct InputLifecycleGenerationTracker: Sendable {
    private var generations: [String: UInt] = [:]

    public init() {}

    public mutating func recordActivation(for application: String) -> UInt {
        let generation = (generations[application] ?? 0) &+ 1
        generations[application] = generation
        return generation
    }

    public func isCurrent(
        application: String,
        generation: UInt
    ) -> Bool {
        generations[application] == generation
    }

    public func shouldRetireController(
        application: String,
        generation: UInt
    ) -> Bool {
        !isCurrent(application: application, generation: generation)
    }
}
