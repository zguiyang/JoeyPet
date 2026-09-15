import Foundation
import OSLog

struct BehaviorEngineConfiguration: Equatable, Sendable {
    var minimumDisplayDuration: TimeInterval = 2.0
    var reentryCooldown: TimeInterval = 3.0
}

struct BehaviorEngine: Sendable {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "BehaviorEngine")

    private(set) var currentBehavior: PetBehavior
    private var activeSignals: [String: SystemSignal] = [:]
    private var stateEnteredAt: Date
    private var lastExitAt: [PetState: Date] = [:]
    private let configuration: BehaviorEngineConfiguration

    init(
        configuration: BehaviorEngineConfiguration = BehaviorEngineConfiguration(),
        now: Date = Date()
    ) {
        self.configuration = configuration
        self.stateEnteredAt = now
        self.currentBehavior = PetBehavior(
            state: .idle,
            priority: 0,
            triggeringSignal: .thermalPressure(level: .nominal),
            decidedAt: now
        )
    }

    mutating func ingest(_ signal: SystemSignal, now: Date) -> PetBehavior {
        if signal.proposedPetState == nil {
            activeSignals.removeValue(forKey: signal.sensorID)
        } else {
            activeSignals[signal.sensorID] = signal
        }
        return evaluate(now: now)
    }

    mutating func evaluate(now: Date) -> PetBehavior {
        let candidate = winningBehavior(at: now)

        if candidate.state == currentBehavior.state {
            return currentBehavior
        }

        if shouldDeferTransition(from: currentBehavior, to: candidate, now: now) {
            return currentBehavior
        }

        if candidate.state != .idle, isInReentryCooldown(for: candidate.state, now: now) {
            return currentBehavior
        }

        if currentBehavior.state != candidate.state, currentBehavior.state != .idle {
            lastExitAt[currentBehavior.state] = now
        }

        currentBehavior = candidate
        stateEnteredAt = now
        Self.logger.info("Pet behavior -> \(candidate.state.rawValue, privacy: .public)")
        return currentBehavior
    }

    private func winningBehavior(at now: Date) -> PetBehavior {
        guard let bestSignal = activeSignals.values.max(by: { $0.behaviorPriority < $1.behaviorPriority }),
              let state = bestSignal.proposedPetState,
              bestSignal.behaviorPriority > 0
        else {
            return PetBehavior(
                state: .idle,
                priority: 0,
                triggeringSignal: .thermalPressure(level: .nominal),
                decidedAt: now
            )
        }

        return PetBehavior(
            state: state,
            priority: bestSignal.behaviorPriority,
            triggeringSignal: bestSignal.kind,
            decidedAt: now
        )
    }

    private func shouldDeferTransition(from current: PetBehavior, to candidate: PetBehavior, now: Date) -> Bool {
        guard current.state != candidate.state else { return false }

        let elapsed = now.timeIntervalSince(stateEnteredAt)
        guard elapsed < configuration.minimumDisplayDuration else { return false }

        if candidate.priority > current.priority {
            return false
        }

        return true
    }

    private func isInReentryCooldown(for state: PetState, now: Date) -> Bool {
        guard let exitedAt = lastExitAt[state] else { return false }
        return now.timeIntervalSince(exitedAt) < configuration.reentryCooldown
    }
}

extension SystemSignal {
    static func debugSignal(for state: PetState, now: Date = Date()) -> SystemSignal {
        switch state {
        case .idle:
            return SystemSignal(
                sensorID: "debug",
                kind: .thermalPressure(level: .nominal),
                severity: .info,
                timestamp: now
            )
        case .sweating:
            return SystemSignal(
                sensorID: "debug",
                kind: .thermalPressure(level: .serious),
                severity: .warning,
                timestamp: now
            )
        case .tired:
            return SystemSignal(
                sensorID: "debug",
                kind: .memoryPressure(level: .warning),
                severity: .warning,
                timestamp: now
            )
        case .carryingTrash:
            return SystemSignal(
                sensorID: "debug",
                kind: .storageLow(
                    availableBytes: SensorThresholds.storageCriticalBytes - 1,
                    thresholdBytes: SensorThresholds.storageCriticalBytes
                ),
                severity: .critical,
                timestamp: now
            )
        }
    }
}
