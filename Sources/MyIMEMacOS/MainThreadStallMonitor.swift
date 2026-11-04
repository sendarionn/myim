import AppKit
import MyIMECore
import os

/// Records when the main thread stops answering, and whether a timer on
/// another thread was late meanwhile, which tells a main thread held up on
/// its own from a process or system that was slow as a whole
final class MainThreadStallMonitor: @unchecked Sendable {
    static let shared = MainThreadStallMonitor()

    private static let tick = DispatchTimeInterval.milliseconds(500)
    private static let tickNanoseconds: UInt64 = 500_000_000
    private static let reportedStallMilliseconds = 1_000

    private static let logger = Logger(
        subsystem: "com.sendarionn.myim",
        category: "main-thread-stall"
    )

    private let queue = DispatchQueue(
        label: "myim.main-thread-stall",
        qos: .userInitiated
    )
    private var timer: DispatchSourceTimer?
    // Touched only on the queue
    private var lastTick: UInt64 = 0
    private var pingSentAt: UInt64?
    private var latestLateness: UInt64 = 0

    private init() {}

    func start() {
        queue.async { [self] in
            guard timer == nil else { return }
            lastTick = DispatchTime.now().uptimeNanoseconds
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(
                deadline: .now() + Self.tick,
                repeating: Self.tick,
                leeway: .milliseconds(100)
            )
            timer.setEventHandler { [weak self] in self?.fire() }
            timer.resume()
            self.timer = timer
        }
    }

    private func fire() {
        let now = DispatchTime.now().uptimeNanoseconds
        let interval = now - lastTick
        lastTick = now
        if interval > Self.tickNanoseconds {
            latestLateness = max(latestLateness, interval - Self.tickNanoseconds)
        }
        // The previous ping is still unanswered while the main thread stalls
        guard pingSentAt == nil else { return }
        pingSentAt = now
        DispatchQueue.main.async { [self] in
            let answered = DispatchTime.now().uptimeNanoseconds
            queue.async { [self] in
                answer(at: answered)
            }
        }
    }

    private func answer(at answered: UInt64) {
        guard let sent = pingSentAt else { return }
        let stall = Int((answered - sent) / 1_000_000)
        let lateness = Int(latestLateness / 1_000_000)
        pingSentAt = nil
        latestLateness = 0
        guard stall >= Self.reportedStallMilliseconds else { return }
        let kind = MainThreadStallClassifier.classify(
            stallMilliseconds: stall,
            latestTimerLatenessMilliseconds: lateness
        )
        let application = NSWorkspace.shared.frontmostApplication?
            .bundleIdentifier ?? "unknown"
        Self.logger.notice(
            "main thread stall ms=\(stall, privacy: .public) kind=\(kind.rawValue, privacy: .public) timerLatenessMs=\(lateness, privacy: .public) frontmost=\(application, privacy: .public)"
        )
    }
}
