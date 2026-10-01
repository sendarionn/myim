public struct InputSessionSnapshot: Equatable, Sendable {
    public let controllerID: String
    public let sessionGeneration: UInt
    public let inputRevision: UInt
    public let input: String
    public let cursorPosition: Int

    public init(
        controllerID: String = "",
        sessionGeneration: UInt,
        inputRevision: UInt,
        input: String = "",
        cursorPosition: Int = 0
    ) {
        self.controllerID = controllerID
        self.sessionGeneration = sessionGeneration
        self.inputRevision = inputRevision
        self.input = input
        self.cursorPosition = cursorPosition
    }

    public func isCurrent(
        controllerID: String = "",
        sessionGeneration: UInt?,
        inputRevision: UInt,
        input: String = "",
        cursorPosition: Int = 0
    ) -> Bool {
        (self.controllerID.isEmpty || controllerID == self.controllerID)
            && sessionGeneration == self.sessionGeneration
            && inputRevision == self.inputRevision
            && (self.input.isEmpty || input == self.input)
            && (self.input.isEmpty || cursorPosition == self.cursorPosition)
    }
}

public struct InputSession: Equatable, Sendable {
    public private(set) var sessionGeneration: UInt?
    public private(set) var inputRevision: UInt = 0
    public private(set) var input = ""
    public private(set) var cursorPosition = 0

    public init() {}

    public mutating func activate(sessionGeneration: UInt) {
        self.sessionGeneration = sessionGeneration
    }

    @discardableResult
    public mutating func synchronize(
        input: String,
        cursorPosition: Int
    ) -> Bool {
        let inputChanged = self.input != input
        if inputChanged {
            inputRevision &+= 1
        }
        self.input = input
        self.cursorPosition = cursorPosition
        return inputChanged
    }

    public func snapshot(controllerID: String) -> InputSessionSnapshot? {
        guard let sessionGeneration else { return nil }
        return InputSessionSnapshot(
            controllerID: controllerID,
            sessionGeneration: sessionGeneration,
            inputRevision: inputRevision,
            input: input,
            cursorPosition: cursorPosition
        )
    }

    public func accepts(
        _ snapshot: InputSessionSnapshot,
        controllerID: String,
        isActive: Bool
    ) -> Bool {
        isActive && snapshot.isCurrent(
            controllerID: controllerID,
            sessionGeneration: sessionGeneration,
            inputRevision: inputRevision,
            input: input,
            cursorPosition: cursorPosition
        )
    }
}
