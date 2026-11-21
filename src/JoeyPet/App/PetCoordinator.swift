import Foundation
import OSLog

@MainActor
final class PetCoordinator {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetCoordinator")
    private let sleepWakeMonitor = SleepWakeMonitor()
    private let ambientScheduler = AmbientBehaviorScheduler()
    private let panelController: PetPanelController

    init(panelController: PetPanelController) {
        self.panelController = panelController
        ambientScheduler.onBehavior = { [weak self] behavior in
            guard let self else { return }
            if behavior == .walking { self.panelController.moveShortDistance() }
            else { _ = self.panelController.petRuntime.perform(behavior) }
        }
    }

    func start() {
        sleepWakeMonitor.onSleep = { [weak self] in
            self?.ambientScheduler.stop()
            self?.panelController.petRuntime.stop()
        }
        sleepWakeMonitor.onWake = { [weak self] in self?.ambientScheduler.update() }
        sleepWakeMonitor.start()
        if let animationID = DebugStateInjector.injectedAnimationID() {
            ambientScheduler.stop()
            panelController.petRuntime.applyDebugAnimation(animationID)
        } else if let behavior = DebugStateInjector.injectedTransientBehavior() {
            ambientScheduler.stop()
            _ = panelController.petRuntime.perform(behavior)
        } else {
            ambientScheduler.update()
        }
        Self.logger.info("Pet companion started")
    }

    func stop() {
        sleepWakeMonitor.stop()
        ambientScheduler.stop()
        panelController.petRuntime.stop()
    }
}
