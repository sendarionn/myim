public struct InputLifecycleGenerationTracker: Sendable {
    private var generations: [String: UInt] = [:]
    public private(set) var globalGeneration: UInt = 0

    public init() {}

    public mutating func recordActivation(
        for application: String,
        supersedesOtherApplications: Bool = true
    ) -> UInt {
        let generation = (generations[application] ?? 0) &+ 1
        generations[application] = generation
        if supersedesOtherApplications {
            globalGeneration &+= 1
        }
        return generation
    }

    @discardableResult
    public mutating func recordAnonymousActivation() -> UInt {
        globalGeneration &+= 1
        return globalGeneration
    }

    public func isCurrent(
        application: String,
        generation: UInt
    ) -> Bool {
        generations[application] == generation
    }

    public func shouldRetireController(
        application: String,
        generation: UInt,
        globalGeneration: UInt
    ) -> Bool {
        !isCurrent(application: application, generation: generation)
            || self.globalGeneration != globalGeneration
    }

    public func shouldRetireController(globalGeneration: UInt) -> Bool {
        self.globalGeneration != globalGeneration
    }
}
