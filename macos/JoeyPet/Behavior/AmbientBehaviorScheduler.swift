import Foundation
import OSLog

/// Pure timing for ambient groom. Callers supply `now` and a random source so
/// tests stay deterministic.
struct AmbientGroomPlanner: Equatable, Sendable {
    /// Next earliest time a groom may fire.
    private(set) var nextDue: Date?
    /// Last time a groom actually started.
    private(set) var lastFiredAt: Date?

    /// Same ambient transient must wait at least this long (DESIGN.md).
    var sameTransientCooldown: TimeInterval = 60
    /// First groom after start sits in this window so the desk is not busy.
    var firstDelayRange: ClosedRange<TimeInterval> = 25...55
    /// After a groom, wait this long before the next candidate check window.
    var repeatDelayRange: ClosedRange<TimeInterval> = 60...120

    mutating func reset(at now: Date, random: (ClosedRange<Double>) -> Double = { Double.random(in: $0) }) {
        lastFiredAt = nil
        nextDue = now.addingTimeInterval(random(firstDelayRange.asDoubleRange))
    }

    mutating func stop() {
        nextDue = nil
        lastFiredAt = nil
    }

    /// Whether the planner believes a groom may be attempted at `now`.
    func isDue(at now: Date) -> Bool {
        guard let nextDue else { return false }
        return now >= nextDue
    }

    /// Record a successful groom and schedule the next earliest attempt.
    mutating func markFired(at now: Date, random: (ClosedRange<Double>) -> Double = { Double.random(in: $0) }) {
        lastFiredAt = now
        let gap = max(sameTransientCooldown, random(repeatDelayRange.asDoubleRange))
        nextDue = now.addingTimeInterval(gap)
    }

    /// Push the next due time forward without counting a fire (gates failed).
    mutating func deferAttempt(at now: Date, by delay: TimeInterval = 12) {
        nextDue = now.addingTimeInterval(delay)
    }
}

private extension ClosedRange where Bound == TimeInterval {
    var asDoubleRange: ClosedRange<Double> {
        Double(lowerBound)...Double(upperBound)
    }
}

/// Low-frequency ambient product moments (currently groom only).
/// Does not drive SpriteKit; it asks `PetRuntime` to play a gated transient.
@MainActor
final class AmbientBehaviorScheduler {
    private static let logger = Logger(
        subsystem: "com.zguiyang.JoeyPet",
        category: "AmbientBehaviorScheduler"
    )

    private let sampleInterval: TimeInterval
    private let sleeper: (TimeInterval) async -> Bool
    private var planner = AmbientGroomPlanner()
    private var task: Task<Void, Never>?

    var onGroom: (() -> Bool)?

    init(
        sampleInterval: TimeInterval = 12,
        sleeper: @escaping (TimeInterval) async -> Bool = AmbientBehaviorScheduler.sleep
    ) {
        self.sampleInterval = sampleInterval
        self.sleeper = sleeper
    }

    func start(at now: Date = Date()) {
        guard task == nil else { return }
        planner.reset(at: now)
        task = Task { [weak self] in
            await self?.run()
        }
        Self.logger.info("Ambient scheduler started")
    }

    func stop() {
        task?.cancel()
        task = nil
        planner.stop()
        Self.logger.info("Ambient scheduler stopped")
    }

    private func run() async {
        while !Task.isCancelled {
            guard await sleeper(sampleInterval), !Task.isCancelled else { break }
            let now = Date()
            guard planner.isDue(at: now) else { continue }

            let played = onGroom?() ?? false
            if played {
                planner.markFired(at: now)
                Self.logger.info("Ambient groom fired")
            } else {
                planner.deferAttempt(at: now)
            }
        }
    }

    private nonisolated static func sleep(_ interval: TimeInterval) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(interval))
            return true
        } catch {
            return false
        }
    }
}
