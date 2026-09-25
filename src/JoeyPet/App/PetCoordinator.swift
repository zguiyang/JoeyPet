import AppKit
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
    private var lastAnnouncedState: PetState = .idle

    var onSystemSnapshot: ((SystemStatusSnapshot) -> Void)?
    var onStageSnapshot: ((JoeyStageSnapshot) -> Void)?
    var onBubble: ((JoeyBubbleMessage, NSRect, (() -> Void)?, (() -> Void)?) -> Void)?
    var onQuickClean: (() -> Void)?
    var onScan: (() -> Void)?

    init(panelController: PetPanelController) {
        self.panelController = panelController
        self.ambientScheduler = AmbientBehaviorScheduler()
        self.ambientScheduler.onBehavior = { [weak self] behavior in
            guard let self else { return }
            if behavior == .walking {
                self.panelController.moveShortDistance()
            } else {
                _ = self.panelController.petRuntime.perform(behavior)
            }
        }
    }

    func start() {
        sensorHub.onSignal = { [weak self] signal in
            self?.handle(signal: signal)
        }
        sensorHub.onSnapshot = { [weak self] snapshot in
            self?.onSystemSnapshot?(snapshot)
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

        publishStageSnapshot()
        Self.logger.info("PetCoordinator started")
    }

    func publishStageSnapshot() {
        let snapshot = JoeyStageSnapshot(
            petState: panelController.petRuntime.currentState,
            transientBehavior: panelController.petRuntime.currentTransientBehavior,
            overallSeverity: sensorHub.currentSnapshot.overallSeverity
        )
        onStageSnapshot?(snapshot)
    }

    func stop() {
        sleepWakeMonitor.stop()
        ambientScheduler.stop()
        panelController.petRuntime.stop()
        sensorHub.stop()
        Self.logger.info("PetCoordinator stopped")
    }

    func refreshPreferences() {
        ambientScheduler.update(sustainedState: behaviorEngine.currentBehavior.state)
    }

    private func handle(signal: SystemSignal) {
        if signal.proposedPetState != nil {
            panelController.stopMovement()
        }
        let behavior = behaviorEngine.ingest(signal, now: signal.timestamp)
        panelController.petRuntime.apply(behavior: behavior)
        panelController.petRuntime.updateStatusSeverity(sensorHub.currentSnapshot.overallSeverity)
        onSystemSnapshot?(sensorHub.currentSnapshot)
        ambientScheduler.update(sustainedState: behavior.state)

        let status = sensorHub.currentSnapshot.overallSeverity
        if behavior.state != lastAnnouncedState,
           behavior.state != .idle,
           status.isActionable,
           PetPreferences.allowsProactiveBubble(isUserInitiated: false) {
            lastAnnouncedState = behavior.state
            let message: JoeyBubbleMessage
            switch behavior.state {
            case .sweating:
                message = JoeyBubbleMessage(text: "Mac 有点热。", severity: status, primaryTitle: nil, secondaryTitle: nil)
            case .tired:
                message = JoeyBubbleMessage(text: "内存有点紧张。", severity: status, primaryTitle: nil, secondaryTitle: nil)
            case .carryingTrash:
                message = JoeyBubbleMessage(text: "磁盘空间有点挤，要清理一下吗？", severity: status, primaryTitle: "快速清理", secondaryTitle: "查看")
            case .idle:
                return
            }
            onBubble?(message, panelController.currentFrame(),
                      message.primaryTitle == nil ? nil : { [weak self] in self?.onQuickClean?() },
                      message.secondaryTitle == nil ? nil : { [weak self] in self?.onScan?() })
        }
        if behavior.state == .idle {
            lastAnnouncedState = .idle
        }
        publishStageSnapshot()
    }
}
