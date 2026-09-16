import Foundation
import OSLog

@MainActor
final class AmbientBehaviorScheduler {
    struct Configuration: Equatable, Sendable {
        var minimumDelay: TimeInterval = 12
        var maximumDelay: TimeInterval = 35

        nonisolated init(minimumDelay: TimeInterval = 12, maximumDelay: TimeInterval = 35) {
            self.minimumDelay = minimumDelay
            self.maximumDelay = maximumDelay
        }
    }

    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "AmbientBehaviorScheduler")

    private let configuration: Configuration
    private let delayProvider: () -> TimeInterval
    private let behaviorProvider: () -> PetTransientBehavior
    private let sleeper: (TimeInterval) async -> Bool
    private let defaults: UserDefaults
    private var task: Task<Void, Never>?

    var onBehavior: ((PetTransientBehavior) -> Void)?
    private(set) var isRunning = false

    init(
        configuration: Configuration = Configuration(),
        delayProvider: @escaping () -> TimeInterval = {
            TimeInterval.random(in: 12...35)
        },
        behaviorProvider: @escaping () -> PetTransientBehavior = AmbientBehaviorScheduler.randomBehavior,
        sleeper: @escaping (TimeInterval) async -> Bool = AmbientBehaviorScheduler.sleep,
        defaults: UserDefaults = .standard
    ) {
        self.configuration = configuration
        self.delayProvider = delayProvider
        self.behaviorProvider = behaviorProvider
        self.sleeper = sleeper
        self.defaults = defaults
    }

    func start() {
        guard task == nil else { return }
        isRunning = true
        task = Task { [weak self] in
            await self?.run()
        }
        Self.logger.info("Ambient scheduler started")
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
        Self.logger.info("Ambient scheduler stopped")
    }

    func update(sustainedState: PetState) {
        let enabled = PetPreferences.ambientBehaviorsEnabled(defaults: defaults)
        if sustainedState == .idle, enabled {
            start()
        } else {
            stop()
        }
    }

    nonisolated static func boundedDelay(_ requested: TimeInterval, configuration: Configuration = Configuration()) -> TimeInterval {
        min(max(requested, configuration.minimumDelay), configuration.maximumDelay)
    }

    private func run() async {
        while !Task.isCancelled {
            let delay = Self.boundedDelay(delayProvider(), configuration: configuration)
            guard await sleeper(delay), !Task.isCancelled else { break }
            guard isRunning, !Task.isCancelled else { break }
            onBehavior?(behaviorProvider())
        }
    }

    private nonisolated static func randomBehavior() -> PetTransientBehavior {
        switch Int.random(in: 0..<100) {
        case 0..<70:
            return .blink
        case 70..<93:
            return .walking
        default:
            return .sleeping
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
