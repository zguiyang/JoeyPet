import CoreGraphics
import Foundation
import OSLog

/// Pure threshold tracking for presence events. It reports each threshold at
/// most once until input returns.
struct PetPresenceTracker {
    let policy: PresencePolicy
    private(set) var hasEnteredIdle = false
    private(set) var hasBeenAway = false

    init(policy: PresencePolicy = PresencePolicy()) {
        self.policy = policy
    }

    /// - Parameter idleSeconds: system input idle time, or `nil` when the source
    ///   is unavailable. `nil` disables doze/yawn without touching other state.
    mutating func update(idleSeconds: TimeInterval?) -> PetEvent? {
        guard let idleSeconds, idleSeconds.isFinite, idleSeconds >= 0 else {
            return nil
        }

        if idleSeconds >= policy.awayThreshold {
            guard !hasBeenAway else { return nil }
            hasBeenAway = true
            hasEnteredIdle = true
            return .presenceAway30
        }

        if idleSeconds >= policy.idleThreshold {
            guard !hasEnteredIdle else { return nil }
            hasEnteredIdle = true
            return .presenceIdle90
        }

        if idleSeconds < Self.returnThreshold, hasEnteredIdle || hasBeenAway {
            reset()
            return .presenceReturned
        }

        return nil
    }

    mutating func reset() {
        hasEnteredIdle = false
        hasBeenAway = false
    }

    /// Sampling runs every few seconds, so "returned" uses a small window rather
    /// than the exact 2-second wake guard.
    private static let returnThreshold: TimeInterval = 5
}

/// Samples system input idle time and forwards presence events to the runtime.
/// It only reads duration, never content, and never asks for permissions.
@MainActor
final class PetPresenceMonitor {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetPresenceMonitor")

    private let idleProvider: () -> TimeInterval?
    private let sampleInterval: TimeInterval
    private let sleeper: (TimeInterval) async -> Bool
    private var tracker: PetPresenceTracker
    private var task: Task<Void, Never>?

    var onEvent: ((PetEvent) -> Void)?

    init(
        policy: PresencePolicy = PresencePolicy(),
        idleProvider: @escaping () -> TimeInterval? = PetPresenceMonitor.systemIdleSeconds,
        sampleInterval: TimeInterval = 5,
        sleeper: @escaping (TimeInterval) async -> Bool = PetPresenceMonitor.sleep
    ) {
        tracker = PetPresenceTracker(policy: policy)
        self.idleProvider = idleProvider
        self.sampleInterval = sampleInterval
        self.sleeper = sleeper
    }

    func start() {
        guard task == nil else { return }
        tracker.reset()
        task = Task { [weak self] in
            await self?.run()
        }
        Self.logger.info("Presence monitor started")
    }

    func stop() {
        task?.cancel()
        task = nil
        tracker.reset()
        Self.logger.info("Presence monitor stopped")
    }

    nonisolated static func systemIdleSeconds() -> TimeInterval? {
        let anyInput = CGEventType(rawValue: ~0) ?? .null
        let seconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: anyInput
        )
        guard seconds.isFinite, seconds >= 0 else { return nil }
        return seconds
    }

    private func run() async {
        while !Task.isCancelled {
            guard await sleeper(sampleInterval), !Task.isCancelled else { break }
            guard let event = tracker.update(idleSeconds: idleProvider()) else { continue }
            onEvent?(event)
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
