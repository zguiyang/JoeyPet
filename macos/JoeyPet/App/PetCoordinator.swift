import AppKit
import Foundation
import OSLog

@MainActor
final class PetCoordinator {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetCoordinator")

    private let sleepWakeMonitor = SleepWakeMonitor()
    private let presenceMonitor: PetPresenceMonitor
    private let ambientScheduler = AmbientBehaviorScheduler()
    private let panelController: PetPanelController
    private var workspaceObservers: [NSObjectProtocol] = []

    /// Forwards every reduced situation together with today's facts.
    var onSituationChanged: ((PetSituation, CompanionSummary) -> Void)?
    /// Forwards the pose the renderer actually shows, transients included.
    var onPoseChanged: ((PetPose) -> Void)?

    init(panelController: PetPanelController) {
        self.panelController = panelController
        presenceMonitor = PetPresenceMonitor(
            policy: panelController.petRuntime.situation.presence
        )
        presenceMonitor.onEvent = { [weak self] event in
            self?.panelController.petRuntime.send(event)
        }
        ambientScheduler.onGroom = { [weak self] in
            self?.panelController.petRuntime.playAmbientGroom() ?? false
        }
        panelController.onSituationChanged = { [weak self] situation in
            guard let self else { return }
            self.onSituationChanged?(situation, self.runtime.summary)
        }
        panelController.petRuntime.onRenderedPoseChanged = { [weak self] pose in
            self?.panelController.syncGreetingTip(for: pose)
            self?.onPoseChanged?(pose)
        }
    }

    private var runtime: PetRuntime { panelController.petRuntime }

    func start() {
        sleepWakeMonitor.onSleep = { [weak self] in
            guard let self else { return }
            self.presenceMonitor.stop()
            self.ambientScheduler.stop()
            self.runtime.send(.systemSleep)
        }
        sleepWakeMonitor.onWake = { [weak self] in
            guard let self else { return }
            self.runtime.send(.systemWake)
            self.presenceMonitor.start()
            self.ambientScheduler.start()
        }
        sleepWakeMonitor.onScreenLocked = { [weak self] in
            guard let self else { return }
            self.presenceMonitor.stop()
            self.ambientScheduler.stop()
            self.runtime.send(.screenLocked)
        }
        sleepWakeMonitor.onScreenUnlocked = { [weak self] in
            guard let self else { return }
            self.runtime.send(.screenUnlocked)
            self.presenceMonitor.start()
            self.ambientScheduler.start()
        }
        sleepWakeMonitor.start()

        observeAccessibility()

        runtime.start()
        panelController.syncGreetingTip(for: runtime.renderedPose)
        onPoseChanged?(runtime.renderedPose)
        presenceMonitor.start()
        ambientScheduler.start()

        if let animationID = DebugStateInjector.injectedAnimationID() {
            runtime.applyDebugAnimation(animationID)
        } else if let behavior = DebugStateInjector.injectedTransientBehavior() {
            _ = runtime.perform(behavior)
        }
        if DebugStateInjector.startsCompanionSession() {
            runtime.startSession()
        }
        Self.logger.info("Pet companion started")
    }

    func stop() {
        sleepWakeMonitor.stop()
        presenceMonitor.stop()
        ambientScheduler.stop()

        let center = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            center.removeObserver(observer)
        }
        workspaceObservers.removeAll()

        runtime.stop()
    }

    /// Mirrors the menu/settings visibility toggle into the runtime state.
    func setVisible(_ visible: Bool) {
        runtime.setVisible(visible)
    }

    /// The user starts companionship from the nest.
    func startSession() {
        runtime.startSession()
    }

    /// The user ends the session from the nest or the desktop menu.
    func endSession() {
        runtime.endSession()
    }

    /// A tap on the nest asks the runtime for one short greeting. The desktop
    /// pet plays the same transient, so both surfaces stay in sync.
    func greetPet() {
        _ = runtime.perform(.greeting)
    }

    /// Debug settings: play one product probe. Callers must ensure the desktop
    /// pet is visible first when the effect lives on the panel.
    @discardableResult
    func debugTrigger(_ action: DebugPetAction) -> Bool {
        if let current = runtime.currentTransientBehavior {
            runtime.finishTransientIfCurrent(current)
        }

        switch action {
        case .showDesktopPet, .posePreview:
            return true
        case .greeting:
            return runtime.perform(.greeting)
        case .notifying:
            runtime.send(.debugForceInvite)
            return true
        case .recovering:
            runtime.send(.debugForceRecover)
            return true
        case .celebrating:
            runtime.send(.debugForceComplete)
            return true
        case .sleeping:
            return runtime.perform(.sleeping)
        case .quietSleep:
            return runtime.debugHoldPose(.sleep, duration: 24)
        case .yawning:
            return runtime.debugHoldPose(.yawn, duration: 1.8)
        case .grooming:
            return runtime.perform(.grooming)
        case .startSession:
            runtime.startSession()
            return true
        case .endSession:
            runtime.endSession()
            return true
        }
    }

    /// Mirrors the Settings do-not-disturb switch into the runtime.
    func setDoNotDisturb(_ enabled: Bool) {
        runtime.setDoNotDisturb(enabled)
    }

    func applyConfiguration(quietWindow: QuietWindow, rhythmMinutes: Int) {
        runtime.applyConfiguration(quietWindow: quietWindow, rhythmMinutes: rhythmMinutes)
    }

    private func observeAccessibility() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.runtime.setReduceMotion(
                        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                    )
                }
            }
        )
    }
}
