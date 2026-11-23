import AppKit
import Foundation
import OSLog
import SpriteKit

/// Minimal rendering surface used by `PetRuntime`. It only draws poses and
/// never reads product state.
@MainActor
protocol PetPoseRendering: AnyObject {
    var skScene: SKScene { get }
    func show(pose: PetPose)
    func setReduceMotion(_ enabled: Bool)
}

/// Renderer used only when the bundled layered package cannot load. It keeps
/// the runtime alive and logs the failure instead of showing placeholder art.
@MainActor
final class EmptyPoseRenderer: PetPoseRendering {
    let skScene: SKScene

    init(size: CGSize) {
        skScene = SKScene(size: size)
        skScene.scaleMode = .aspectFill
    }

    func show(pose: PetPose) {}
    func setReduceMotion(_ enabled: Bool) {}
}

/// The single behavior entry point.
///
/// `PetRuntime` reduces domain events, executes their effects and renders one
/// pose. Callers never drive the scene directly.
@MainActor
final class PetRuntime {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetRuntime")

    private let renderer: PetPoseRendering
    private let store: PetSessionStoring
    private let now: () -> Date
    private let calendar: Calendar
    private let reduceMotionProvider: () -> Bool

    private(set) var situation: PetSituation
    private(set) var renderedPose: PetPose
    private(set) var currentTransientBehavior: PetTransientBehavior?

    /// Notifies the host after every reduced event so UI labels can follow the state.
    var onSituationChanged: ((PetSituation) -> Void)?
    /// Notifies the host whenever the renderer actually switches pose, including
    /// ambient transients. The nest mirrors this value so both surfaces agree.
    var onRenderedPoseChanged: ((PetPose) -> Void)?

    private var persisted: PetPersistedState
    private var lastCompanionshipSampleAt: Date?
    private var transientPose: PetPose?
    private var transientID: UUID?
    private var transientTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var isStarted = false

    var scene: SKScene { renderer.skScene }
    var currentState: PetState { .idle }

    /// Today's companionship and break facts for the nest and reflection views.
    var summary: CompanionSummary {
        CompanionSummary(
            todayCompanionship: TimeInterval(persisted.todayCompanionshipSeconds),
            todayBreaks: persisted.todayBreaks,
            weekBreakCounts: persisted.weekBreakCounts
        )
    }

    convenience init(sceneSize: CGSize) {
        self.init(
            renderer: Self.makeRenderer(sceneSize: sceneSize),
            store: UserDefaultsPetSessionStore(),
            now: Date.init,
            calendar: .autoupdatingCurrent,
            reduceMotionProvider: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        )
    }

    init(
        renderer: PetPoseRendering,
        store: PetSessionStoring,
        now: @escaping () -> Date,
        calendar: Calendar = .autoupdatingCurrent,
        reduceMotionProvider: @escaping () -> Bool = { false }
    ) {
        self.renderer = renderer
        self.store = store
        self.now = now
        self.calendar = calendar
        self.reduceMotionProvider = reduceMotionProvider

        let date = now()
        let restored = store.load(now: date, calendar: calendar)
        var restoredSituation = PetSituation.restored(from: restored, now: date, calendar: calendar)
        restoredSituation.isReduceMotion = reduceMotionProvider()

        persisted = restored
        situation = restoredSituation
        renderedPose = restoredSituation.resolvedPose(at: date)

        renderer.setReduceMotion(restoredSituation.isReduceMotion)
        renderer.show(pose: renderedPose)
    }

    // MARK: - Lifecycle

    func start() {
        guard !isStarted else { return }
        isStarted = true
        send(.tick)
        Self.logger.info("PetRuntime started")
    }

    func stop() {
        isStarted = false
        tickTask?.cancel()
        tickTask = nil
        transientTask?.cancel()
        transientTask = nil
        transientPose = nil
        transientID = nil
        currentTransientBehavior = nil

        let date = now()
        updateCompanionship(at: date)
        persist(at: date)
        lastCompanionshipSampleAt = nil
        Self.logger.info("PetRuntime stopped")
    }

    // MARK: - Events

    /// The only mutation entry point. Views pass user or system events here.
    func send(_ event: PetEvent) {
        let date = now()
        let sessionClockPaused = event == .systemSleep || event == .screenLocked

        updateCompanionship(at: date)

        let transition = PetStateMachine.reduce(
            situation,
            event: event,
            now: date,
            calendar: calendar
        )
        situation = transition.state

        // A pose that must win (sleep, drag, invitation, session) cuts any
        // ambient transient short instead of letting it finish over it. A
        // greeting is a direct response to the user, so it plays out.
        if situation.interruptsAmbientTransient,
           currentTransientBehavior != .greeting {
            clearTransient()
        }

        if sessionClockPaused {
            lastCompanionshipSampleAt = nil
        } else if situation.session == nil {
            lastCompanionshipSampleAt = nil
        } else if lastCompanionshipSampleAt == nil {
            lastCompanionshipSampleAt = date
        }

        renderer.setReduceMotion(situation.isReduceMotion)
        execute(transition.effects, at: date)
        rescheduleTick()
        onSituationChanged?(situation)
    }

    func startSession() {
        send(.sessionStart)
    }

    func endSession() {
        send(.sessionEnd)
    }

    func setVisible(_ visible: Bool) {
        send(visible ? .showRequested : .hideRequested)
    }

    func applyConfiguration(quietWindow: QuietWindow, rhythmMinutes: Int) {
        send(.configurationChanged(quietWindow: quietWindow, rhythmMinutes: rhythmMinutes))
    }

    /// Mirrors the Settings do-not-disturb switch into the runtime.
    func setDoNotDisturb(_ enabled: Bool) {
        send(.doNotDisturbChanged(enabled))
    }

    func setReduceMotion(_ enabled: Bool) {
        send(.reduceMotionChanged(enabled))
    }

    // MARK: - Legacy compatibility

    /// Kept for the Debug launch arguments and the still-unmigrated panel movement.
    @discardableResult
    func perform(_ behavior: PetTransientBehavior) -> Bool {
        guard transientPose == nil, currentTransientBehavior == nil else { return false }
        // A greeting is a response from the nest, so it may play while the
        // desktop pet itself is hidden; the panel never appears because of it.
        guard situation.resolvedDesktop(at: now()) != .hidden
            || behavior == .greeting
        else {
            return false
        }
        if behavior == .walking, !situation.canWalkAmbiently(at: now()) {
            return false
        }
        switch situation.companion {
        case .invite, .recover, .complete:
            return false
        default:
            break
        }
        guard let pose = Self.pose(for: behavior) else { return false }

        playTransient(
            pose: pose,
            duration: behavior.sessionDuration ?? 3,
            behavior: behavior
        )
        Self.logger.info("PetRuntime transient -> \(behavior.rawValue, privacy: .public)")
        return true
    }

    func finishTransientIfCurrent(_ behavior: PetTransientBehavior) {
        guard currentTransientBehavior == behavior else { return }
        transientTask?.cancel()
        endTransient(id: transientID)
    }

    /// Direct asset playback hook for Debug builds; it never changes the domain state.
    func applyDebugAnimation(_ animationID: String) {
        if animationID == "idle" {
            clearTransient()
            return
        }
        if let pose = PetPose(rawValue: animationID) {
            clearTransient()
            playTransient(pose: pose, duration: 3)
            return
        }
        if let behavior = PetTransientBehavior(rawValue: animationID) {
            _ = perform(behavior)
        }
    }

    // MARK: - Tick scheduling

    /// The next moment that can change the situation. Also capped at 60 seconds
    /// so wall-clock changes and day boundaries are picked up.
    func nextWakeDate(after date: Date) -> Date? {
        guard !situation.isSystemSleeping, !situation.isScreenLocked else { return nil }

        var deadlines: [Date] = []
        if let snoozeUntil = situation.snoozeUntil, snoozeUntil > date {
            deadlines.append(snoozeUntil)
        }
        if let revealDeadline = situation.hiddenRevealDeadline(), revealDeadline > date {
            deadlines.append(revealDeadline)
        }
        if let dragSettledAt = situation.dragSettledAt, dragSettledAt > date {
            deadlines.append(dragSettledAt)
        }
        if situation.companion == .recover,
           let ends = situation.recoveryEndsAt, ends > date {
            deadlines.append(ends)
        }
        if situation.companion == .complete,
           let ends = situation.completeEndsAt, ends > date {
            deadlines.append(ends)
        }
        if situation.isYawning, let until = situation.yawnUntil, until > date {
            deadlines.append(until)
        }
        if situation.session != nil {
            if let approach = situation.approachStartDate(), approach > date {
                deadlines.append(approach)
            }
            if let due = situation.invitationDueDate(), due > date {
                deadlines.append(due)
            }
        }
        if let boundary = situation.quietWindow.nextBoundary(after: date, calendar: calendar),
           boundary > date {
            deadlines.append(boundary)
        }

        guard let earliest = deadlines.min() else { return nil }
        return min(earliest, date.addingTimeInterval(60))
    }

    private func rescheduleTick() {
        tickTask?.cancel()
        tickTask = nil

        guard isStarted else { return }
        let date = now()
        guard let deadline = nextWakeDate(after: date) else { return }

        let interval = max(0.05, deadline.timeIntervalSince(date))
        tickTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.send(.tick)
        }
    }

    // MARK: - Effects

    private func execute(_ effects: [PetEffect], at date: Date) {
        for effect in effects {
            switch effect {
            case let .play(pose):
                guard transientPose == nil else { continue }
                render(pose)

            case .showInviteCard:
                Self.logger.info("Invite card requested; UI lands in PR5")
            case .dismissInviteCard:
                Self.logger.debug("Invite card dismissed")
            case .showRecoveryPanel:
                Self.logger.info("Recovery panel requested; UI lands in PR5")
            case .hideRecoveryPanel:
                Self.logger.debug("Recovery panel hidden")

            case .completeRecovery:
                recordCompletedBreak(at: date)

            case .playCarry:
                playCarryReturn()

            case .pauseAmbient, .resumeAmbient, .freeze, .resume:
                break

            case .persist:
                persist(at: date)

            case let .log(message):
                Self.logger.debug("\(message, privacy: .public)")
            }
        }
    }

    private func render(_ pose: PetPose) {
        guard pose != renderedPose else { return }
        renderedPose = pose
        renderer.show(pose: pose)
        onRenderedPoseChanged?(pose)
        Self.logger.info("Pose -> \(pose.rawValue, privacy: .public)")
    }

    private func renderCurrentPose() {
        render(situation.resolvedPose(at: now()))
    }

    /// The brief "carrying a leaf home" beat after a completed break.
    private func playCarryReturn() {
        guard !situation.isReduceMotion,
              transientPose == nil,
              currentTransientBehavior == nil,
              situation.resolvedDesktop(at: now()) != .hidden
        else {
            return
        }
        playTransient(
            pose: .carry,
            duration: PetTransientBehavior.carrying.sessionDuration ?? 3.6,
            behavior: .carrying
        )
    }

    // MARK: - Transient poses

    private func playTransient(
        pose: PetPose,
        duration: TimeInterval,
        behavior: PetTransientBehavior? = nil
    ) {
        let id = UUID()
        transientID = id
        transientPose = pose
        currentTransientBehavior = behavior
        render(pose)

        transientTask?.cancel()
        transientTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.endTransient(id: id)
        }
    }

    private func endTransient(id: UUID?) {
        guard let id, transientID == id else { return }
        clearTransient()
    }

    private func clearTransient() {
        transientTask?.cancel()
        transientTask = nil
        transientID = nil
        transientPose = nil
        currentTransientBehavior = nil
        renderCurrentPose()
    }

    // MARK: - Persistence

    private func persist(at date: Date) {
        var state = persisted.normalized(now: date, calendar: calendar)
        state.isDoNotDisturb = situation.isDoNotDisturb
        state.lastInvitationClosedAt = situation.lastInvitationClosedAt
        state.quietWindow = situation.quietWindow
        state.rhythmMinutes = situation.policy.rhythmMinutes
        state.showsDesktopPet = !situation.isHidden
        persisted = state
        store.save(state)
    }

    private func updateCompanionship(at date: Date) {
        guard situation.session != nil else {
            lastCompanionshipSampleAt = nil
            return
        }
        guard let last = lastCompanionshipSampleAt else {
            lastCompanionshipSampleAt = date
            return
        }

        let startOfDay = calendar.startOfDay(for: date)
        let from = max(last, startOfDay)
        let seconds = date.timeIntervalSince(from)
        guard seconds >= 1 else { return }

        var state = persisted.normalized(now: date, calendar: calendar)
        state.todayCompanionshipSeconds += Int(seconds.rounded(.down))
        persisted = state
        lastCompanionshipSampleAt = date
        store.save(state)
    }

    private func recordCompletedBreak(at date: Date) {
        var state = persisted.normalized(now: date, calendar: calendar)
        state.todayBreaks += 1
        let index = PetDayKey.weekdayIndex(for: date, calendar: calendar)
        if state.weekBreakCounts.indices.contains(index) {
            state.weekBreakCounts[index] += 1
        }
        persisted = state
    }

    // MARK: - Composition

    private static func pose(for behavior: PetTransientBehavior) -> PetPose? {
        switch behavior {
        case .blink:
            return nil
        case .walking:
            return .step
        case .carrying:
            return .carry
        case .sleeping:
            return .doze
        case .celebrating:
            return .happy
        case .greeting:
            return .happy
        case .notifying:
            return .sign
        }
    }

    private static func makeRenderer(sceneSize: CGSize) -> PetPoseRendering {
        if let package = JoeyAssetPackage.load() {
            return JoeyDesktopScene(size: sceneSize, package: package)
        }

        logger.error("Layered pet package unavailable; the desktop pet will stay empty")
        return EmptyPoseRenderer(size: sceneSize)
    }
}
