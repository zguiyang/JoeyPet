import Foundation
import OSLog

@MainActor
final class PetCoordinator {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetCoordinator")

    private let sensorHub = SensorHub()
    private let sleepWakeMonitor = SleepWakeMonitor()
    private let ambientScheduler: AmbientBehaviorScheduler
    private var behaviorEngine = BehaviorEngine()
    private let panelController: PetPanelController

    init(panelController: PetPanelController) {
        self.panelController = panelController
        self.ambientScheduler = AmbientBehaviorScheduler()
        self.ambientScheduler.onBehavior = { [weak self] behavior in
            guard let self else { return }
            _ = self.panelController.petRuntime.perform(behavior)
        }
    }

    func start() {
        sensorHub.onSignal = { [weak self] signal in
            self?.handle(signal: signal)
        }

        sleepWakeMonitor.onSleep = { [weak self] in
            self?.ambientScheduler.stop()
            self?.panelController.petRuntime.stop()
            self?.sensorHub.stop()
        }
        sleepWakeMonitor.onWake = { [weak self] in
            guard DebugStateInjector.injectedAnimationID() == nil,
                  DebugStateInjector.injectedTransientBehavior() == nil,
                  DebugStateInjector.injectedPetState() == nil else { return }
            self?.sensorHub.start()
            self?.ambientScheduler.update(sustainedState: self?.behaviorEngine.currentBehavior.state ?? .idle)
        }

        sleepWakeMonitor.start()

        if let debugState = DebugStateInjector.injectedPetState() {
            Self.logger.info("Injecting debug state \(debugState.rawValue, privacy: .public)")
            let signal = SystemSignal.debugSignal(for: debugState)
            handle(signal: signal)
        }

        if let debugAnimation = DebugStateInjector.injectedAnimationID() {
            ambientScheduler.stop()
            panelController.petRuntime.applyDebugAnimation(debugAnimation)
            Self.logger.info("Injecting debug animation \(debugAnimation, privacy: .public)")
        } else if let debugBehavior = DebugStateInjector.injectedTransientBehavior() {
            ambientScheduler.stop()
            _ = panelController.petRuntime.perform(debugBehavior)
            Self.logger.info("Injecting debug behavior \(debugBehavior.rawValue, privacy: .public)")
        } else if DebugStateInjector.injectedPetState() != nil {
            ambientScheduler.stop()
        } else {
            sensorHub.start()
        }

        Self.logger.info("PetCoordinator started")
    }

    func stop() {
        sleepWakeMonitor.stop()
        ambientScheduler.stop()
        panelController.petRuntime.stop()
        sensorHub.stop()
        Self.logger.info("PetCoordinator stopped")
    }

    private func handle(signal: SystemSignal) {
        let behavior = behaviorEngine.ingest(signal, now: signal.timestamp)
        panelController.petRuntime.apply(behavior: behavior)
        ambientScheduler.update(sustainedState: behavior.state)
    }
}
