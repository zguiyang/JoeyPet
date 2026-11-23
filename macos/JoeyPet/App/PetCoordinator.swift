import AppKit
import Foundation
import OSLog

@MainActor
final class PetCoordinator {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetCoordinator")

    private let sleepWakeMonitor = SleepWakeMonitor()
    private let presenceMonitor: PetPresenceMonitor
    private let panelController: PetPanelController
    private var workspaceObservers: [NSObjectProtocol] = []
    private var ambientTask: Task<Void, Never>?

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
        panelController.onSituationChanged = { [weak self] situation in
            guard let self else { return }
            self.onSituationChanged?(situation, self.runtime.summary)
        }
        panelController.petRuntime.onRenderedPoseChanged = { [weak self] pose in
            self?.onPoseChanged?(pose)
        }
    }

    private var runtime: PetRuntime { panelController.petRuntime }

    func start() {
        sleepWakeMonitor.onSleep = { [weak self] in
            guard let self else { return }
            self.presenceMonitor.stop()
            self.runtime.send(.systemSleep)
        }
        sleepWakeMonitor.onWake = { [weak self] in
            guard let self else { return }
            self.runtime.send(.systemWake)
            self.presenceMonitor.start()
        }
        sleepWakeMonitor.onScreenLocked = { [weak self] in
            guard let self else { return }
            self.presenceMonitor.stop()
            self.runtime.send(.screenLocked)
        }
        sleepWakeMonitor.onScreenUnlocked = { [weak self] in
            guard let self else { return }
            self.runtime.send(.screenUnlocked)
            self.presenceMonitor.start()
        }
        sleepWakeMonitor.start()

        observeAccessibility()

        runtime.start()
        onPoseChanged?(runtime.renderedPose)
        presenceMonitor.start()
        startAmbientSteps()

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

        let center = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            center.removeObserver(observer)
        }
        workspaceObservers.removeAll()

        ambientTask?.cancel()
        ambientTask = nil
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

    /// Mirrors the Settings do-not-disturb switch into the runtime.
    func setDoNotDisturb(_ enabled: Bool) {
        runtime.setDoNotDisturb(enabled)
    }

    func applyConfiguration(quietWindow: QuietWindow, rhythmMinutes: Int) {
        runtime.applyConfiguration(quietWindow: quietWindow, rhythmMinutes: rhythmMinutes)
    }

    /// Low-frequency ambient walks. Each pass is a single randomized sleep, so
    /// there is no polling, display link or timer burst.
    private func startAmbientSteps() {
        ambientTask?.cancel()
        ambientTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = AmbientStepPolicy().nextDelay(
                    lowPower: self.runtime.situation.isLowPowerMode
                )
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                self.panelController.moveShortDistance()
            }
        }
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
