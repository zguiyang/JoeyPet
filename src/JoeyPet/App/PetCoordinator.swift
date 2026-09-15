import Foundation
import OSLog

@MainActor
final class PetCoordinator {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetCoordinator")

    private let sensorHub = SensorHub()
    private let sleepWakeMonitor = SleepWakeMonitor()
    private var behaviorEngine = BehaviorEngine()
    private let panelController: PetPanelController

    init(panelController: PetPanelController) {
        self.panelController = panelController
    }

    func start() {
        sensorHub.onSignal = { [weak self] signal in
            self?.handle(signal: signal)
        }

        sleepWakeMonitor.onSleep = { [weak self] in
            self?.sensorHub.stop()
        }
        sleepWakeMonitor.onWake = { [weak self] in
            self?.sensorHub.start()
        }

        sleepWakeMonitor.start()
        sensorHub.start()

        if let debugState = DebugStateInjector.injectedPetState() {
            Self.logger.info("Injecting debug state \(debugState.rawValue, privacy: .public)")
            let signal = SystemSignal.debugSignal(for: debugState)
            handle(signal: signal)
        }

        Self.logger.info("PetCoordinator started")
    }

    func stop() {
        sleepWakeMonitor.stop()
        sensorHub.stop()
        Self.logger.info("PetCoordinator stopped")
    }

    private func handle(signal: SystemSignal) {
        let behavior = behaviorEngine.ingest(signal, now: signal.timestamp)
        panelController.petRuntime.apply(behavior: behavior)
    }
}
