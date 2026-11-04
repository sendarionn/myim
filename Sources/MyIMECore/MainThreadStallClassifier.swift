/// Tells a main thread that was held up alone from a process or system that
/// was slow as a whole, by how late a timer on another thread ran meanwhile
public enum MainThreadStallKind: String, Equatable, Sendable {
    /// Other threads kept running: the main thread was waiting or busy
    case mainThreadOnly = "main-thread-only"
    /// Other threads were late too: CPU, memory, or disk across the process
    /// or the system
    case processOrSystemWide = "process-or-system-wide"
}

public enum MainThreadStallClassifier {
    public static func classify(
        stallMilliseconds: Int,
        latestTimerLatenessMilliseconds: Int
    ) -> MainThreadStallKind {
        latestTimerLatenessMilliseconds * 4 >= stallMilliseconds
            ? .processOrSystemWide
            : .mainThreadOnly
    }
}
