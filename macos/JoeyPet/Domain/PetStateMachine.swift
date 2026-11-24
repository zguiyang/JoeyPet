import Foundation

enum PetEffect: Equatable, Sendable {
    case play(PetPose)
    case showInviteCard
    case dismissInviteCard
    case showRecoveryPanel
    case hideRecoveryPanel
    case completeRecovery
    /// Short "carrying a leaf home" moment after a completed break.
    case playCarry
    case pauseAmbient
    case resumeAmbient
    case freeze
    case resume
    case persist
    case log(String)
}

enum PetEvent: Equatable, Sendable {
    case tick
    case sessionStart
    case sessionEnd
    case inviteAccepted
    case snoozeRequested
    case doNotDisturbChanged(Bool)
    case inviteDismissed
    case recoverySkipped
    case recoveryFinished
    case completeFinished
    case dragBegan
    case dragEnded
    case hideRequested
    case showRequested
    case menuOpened
    case menuClosed
    case quietWindowChanged(Bool)
    case configurationChanged(quietWindow: QuietWindow, rhythmMinutes: Int)
    case systemSleep
    case systemWake
    case screenLocked
    case screenUnlocked
    case presenceIdle90
    case presenceAway30
    case presenceReturned
    case reduceMotionChanged(Bool)
    case lowPowerChanged(Bool)
    case ambientBehaviorsChanged(Bool)
    /// Debug / preview only: jump straight into a companion surface so the
    /// matching card or panel can be reviewed with the pet pose.
    case debugForceInvite
    case debugForceRecover
    case debugForceComplete
}

struct PetTransition: Equatable, Sendable {
    let state: PetSituation
    let effects: [PetEffect]
}

/// Pure reducer for the pet's product state.
///
/// It never reads the clock, writes UserDefaults or touches AppKit/SpriteKit.
/// Callers pass `now` and execute the returned effects.
enum PetStateMachine {
    static func reduce(
        _ state: PetSituation,
        event: PetEvent,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> PetTransition {
        if event == .systemSleep {
            var next = state
            next.isSystemSleeping = true
            return PetTransition(state: next, effects: [.freeze])
        }
        if event == .screenLocked {
            var next = state
            next.isScreenLocked = true
            return PetTransition(state: next, effects: [.freeze])
        }
        if event == .systemWake {
            var next = state
            next.isSystemSleeping = false
            normalize(&next, now: now, calendar: calendar)
            return finish(next, old: state, now: now, effects: [.resume])
        }
        if event == .screenUnlocked {
            var next = state
            next.isScreenLocked = false
            normalize(&next, now: now, calendar: calendar)
            return finish(next, old: state, now: now, effects: [.resume])
        }

        var next = state
        var effects: [PetEffect] = []
        normalize(&next, now: now, calendar: calendar)

        switch event {
        case .tick:
            guard !next.isSystemSleeping, !next.isScreenLocked else { break }
            tick(&next, now: now, calendar: calendar, effects: &effects)

        case .sessionStart:
            guard next.session == nil else { break }
            next.session = CompanionSession(startedAt: now)
            next.companion = .idle
            next.inviteShownAt = nil
            next.snoozeUntil = nil
            next.snoozeUsedThisSession = false
            next.recoveryEndsAt = nil
            next.completeEndsAt = nil
            next.isDozing = false
            next.isYawning = false
            next.yawnUntil = nil
            next.wasAwayLong = false
            effects.append(.persist)

        case .debugForceInvite:
            prepareDebugCompanionSurface(&next, at: now)
            presentInvite(&next, at: now)
            effects.append(.persist)

        case .debugForceRecover:
            prepareDebugCompanionSurface(&next, at: now)
            next.companion = .recover
            next.recoveryEndsAt = now.addingTimeInterval(next.policy.recoveryDuration)
            next.completeEndsAt = nil
            next.inviteShownAt = nil
            effects.append(.persist)

        case .debugForceComplete:
            prepareDebugCompanionSurface(&next, at: now)
            next.companion = .complete
            next.completeEndsAt = now.addingTimeInterval(next.policy.completeDuration)
            next.recoveryEndsAt = nil
            next.inviteShownAt = nil
            // Skip `.completeRecovery` so Debug previews do not bump break counts.
            effects.append(.persist)

        case .sessionEnd:
            next.session = nil
            next.companion = nil
            next.inviteShownAt = nil
            next.snoozeUntil = nil
            next.snoozeUsedThisSession = false
            next.recoveryEndsAt = nil
            next.completeEndsAt = nil
            next.isDozing = false
            next.isYawning = false
            next.yawnUntil = nil
            next.wasAwayLong = false
            effects.append(.persist)

        case .inviteAccepted:
            guard next.session != nil, next.companion == .invite else { break }
            next.companion = .recover
            next.recoveryEndsAt = now.addingTimeInterval(next.policy.recoveryDuration)
            next.lastInvitationClosedAt = now
            next.inviteShownAt = nil
            next.isDozing = false
            next.isYawning = false
            next.yawnUntil = nil
            effects.append(.persist)

        case .snoozeRequested:
            guard next.session != nil, next.companion == .invite else { break }
            if !next.snoozeUsedThisSession {
                next.snoozeUsedThisSession = true
                next.snoozeUntil = now.addingTimeInterval(
                    TimeInterval(next.policy.snoozeMinutes) * 60
                )
            }
            next.companion = .idle
            next.lastInvitationClosedAt = now
            next.inviteShownAt = nil
            effects.append(.persist)

        case let .doNotDisturbChanged(enabled):
            next.isDoNotDisturb = enabled
            if enabled {
                suppressPrompts(&next, now: now)
            } else {
                reflowInvitation(&next, now: now)
            }
            next.isDozing = false
            next.isYawning = false
            next.yawnUntil = nil
            effects.append(.persist)

        case .inviteDismissed:
            guard next.companion == .invite else { break }
            next.companion = next.session != nil ? .idle : nil
            next.lastInvitationClosedAt = now
            next.inviteShownAt = nil
            effects.append(.persist)

        case .recoverySkipped:
            guard next.companion == .recover else { break }
            next.companion = next.session != nil ? .idle : nil
            next.recoveryEndsAt = nil
            next.lastInvitationClosedAt = now
            next.inviteShownAt = nil
            effects.append(.persist)

        case .recoveryFinished:
            guard next.session != nil, next.companion == .recover else { break }
            next.companion = .complete
            next.completeEndsAt = now.addingTimeInterval(next.policy.completeDuration)
            next.recoveryEndsAt = nil
            next.lastInvitationClosedAt = now
            next.inviteShownAt = nil
            effects.append(.completeRecovery)
            effects.append(.persist)

        case .completeFinished:
            guard next.companion == .complete else { break }
            finishCompletion(&next, effects: &effects, now: now)
            effects.append(.persist)

        case .dragBegan:
            next.isDragging = true
            next.dragSettledAt = nil
            next.isDozing = false
            next.isYawning = false
            next.yawnUntil = nil
            effects.append(.pauseAmbient)

        case .dragEnded:
            guard next.isDragging else { break }
            next.isDragging = false
            next.dragSettledAt = now.addingTimeInterval(0.6)
            effects.append(.resumeAmbient)

        case .hideRequested:
            next.isHidden = true
            // Hiding closes whatever is on screen; hidden mode only re-surfaces
            // for invitations that are still due.
            if next.companion == .invite {
                next.companion = next.session != nil ? .idle : nil
                next.lastInvitationClosedAt = now
            } else if next.companion == .recover {
                next.companion = next.session != nil ? .idle : nil
                next.recoveryEndsAt = nil
                effects.append(.log("recoveryCancelledByHide"))
            } else if next.companion == .complete {
                next.companion = next.session != nil ? .idle : nil
                next.completeEndsAt = nil
            }
            next.inviteShownAt = nil
            next.isDozing = false
            next.isYawning = false
            next.yawnUntil = nil
            effects.append(.pauseAmbient)
            effects.append(.persist)

        case .showRequested:
            next.isHidden = false
            next.inviteShownAt = nil
            effects.append(.resumeAmbient)
            reflowInvitation(&next, now: now)
            effects.append(.persist)

        case .menuOpened:
            next.isMenuOpen = true
            effects.append(.pauseAmbient)

        case .menuClosed:
            next.isMenuOpen = false
            effects.append(.resumeAmbient)
            reflowInvitation(&next, now: now)

        case .quietWindowChanged:
            // `normalize` already recomputed the window from the local clock.
            break

        case let .configurationChanged(window, rhythmMinutes):
            next.quietWindow = window
            next.policy.rhythmMinutes = rhythmMinutes
            normalize(&next, now: now, calendar: calendar)
            reflowInvitation(&next, now: now)
            effects.append(.persist)

        case .presenceIdle90:
            guard !next.isDozing, next.canEnterDoze(at: now) else { break }
            next.isDozing = true
            next.isYawning = false
            next.yawnUntil = nil
            effects.append(.pauseAmbient)

        case .presenceAway30:
            guard next.canEnterDoze(at: now) else { break }
            next.wasAwayLong = true
            if !next.isDozing {
                next.isDozing = true
                next.isYawning = false
                next.yawnUntil = nil
                effects.append(.pauseAmbient)
            }

        case .presenceReturned:
            guard next.isDozing || next.wasAwayLong else { break }
            next.wasAwayLong = false
            beginLifeYawn(&next, at: now)
            effects.append(.pauseAmbient)

        case let .reduceMotionChanged(enabled):
            next.isReduceMotion = enabled
            effects.append(enabled ? .pauseAmbient : .resumeAmbient)

        case let .lowPowerChanged(enabled):
            next.isLowPowerMode = enabled
            effects.append(.log("lowPower=\(enabled)"))

        case let .ambientBehaviorsChanged(enabled):
            next.isAmbientEnabled = enabled
            effects.append(enabled ? .resumeAmbient : .pauseAmbient)

        case .systemSleep, .systemWake, .screenLocked, .screenUnlocked:
            break
        }

        normalize(&next, now: now, calendar: calendar)
        return finish(next, old: state, now: now, effects: effects)
    }

    // MARK: - Helpers

    private static func normalize(
        _ state: inout PetSituation,
        now: Date,
        calendar: Calendar
    ) {
        let wasQuiet = state.isQuietActive
        state.isQuietActive = state.quietWindow.isActive(at: now, calendar: calendar)

        if state.session == nil {
            state.companion = nil
            state.recoveryEndsAt = nil
            state.completeEndsAt = nil
            state.inviteShownAt = nil
        }

        if state.isDoNotDisturb {
            suppressPrompts(&state, now: now)
        } else if state.isQuietActive {
            switch state.companion {
            case .invite:
                state.companion = state.session != nil ? .idle : nil
                state.lastInvitationClosedAt = now
                state.inviteShownAt = nil
            case .approach:
                state.companion = state.session != nil ? .idle : nil
            default:
                break
            }
        } else if state.session != nil, state.companion == nil {
            state.companion = .idle
        }

        // Life-like quiet bridges: yawn before sinking into sleep, and yawn again
        // when the window ends. Skip enter-yawn while recovery/complete still owns
        // the pose; those finish first, then settle into sleep.
        if !wasQuiet, state.isQuietActive {
            switch state.companion {
            case .recover, .complete:
                break
            default:
                beginLifeYawn(&state, at: now)
            }
        } else if wasQuiet, !state.isQuietActive {
            beginLifeYawn(&state, at: now)
        }
    }

    /// Short wake/settle yawn used for presence return and quiet-hour edges.
    private static func beginLifeYawn(_ state: inout PetSituation, at now: Date) {
        state.isDozing = false
        state.isYawning = true
        state.yawnUntil = now.addingTimeInterval(state.presence.yawnDuration)
    }

    /// Do-not-disturb closes every surface that could interrupt the user.
    private static func suppressPrompts(_ state: inout PetSituation, now: Date) {
        switch state.companion {
        case .invite:
            state.companion = state.session != nil ? .idle : nil
            state.lastInvitationClosedAt = now
        case .recover:
            state.companion = state.session != nil ? .idle : nil
            state.recoveryEndsAt = nil
        case .complete:
            state.companion = state.session != nil ? .idle : nil
            state.completeEndsAt = nil
        case .approach:
            state.companion = state.session != nil ? .idle : nil
        default:
            break
        }
        state.inviteShownAt = nil
    }

    private static func tick(
        _ state: inout PetSituation,
        now: Date,
        calendar: Calendar,
        effects: inout [PetEffect]
    ) {
        if let snoozeUntil = state.snoozeUntil, snoozeUntil <= now {
            state.snoozeUntil = nil
            if state.session != nil, canPresentInvite(state, now: now, bypassGap: true) {
                presentInvite(&state, at: now)
                effects.append(.persist)
            } else {
                if state.session != nil { state.companion = .idle }
                effects.append(.log("snoozeRetryDropped"))
                effects.append(.persist)
            }
        }

        // A hidden Joey surfaces briefly for one invitation, then slips away
        // again and treats the unopened invitation as "later". Do not yank the
        // card away while the user is in the menu or dragging him.
        if !state.isMenuOpen, !state.isDragging,
           let deadline = state.hiddenRevealDeadline(), deadline <= now {
            closeHiddenInvite(&state, now: now)
            effects.append(.log("hiddenInviteTimedOut"))
            effects.append(.persist)
        }

        if state.companion == .recover,
           let ends = state.recoveryEndsAt,
           ends <= now {
            state.recoveryEndsAt = nil
            state.companion = .complete
            state.completeEndsAt = now.addingTimeInterval(state.policy.completeDuration)
            state.lastInvitationClosedAt = now
            effects.append(.completeRecovery)
            effects.append(.persist)
        }

        if state.companion == .complete,
           let ends = state.completeEndsAt,
           ends <= now {
            finishCompletion(&state, effects: &effects, now: now)
            effects.append(.persist)
        }

        if state.isYawning, let until = state.yawnUntil, until <= now {
            state.isYawning = false
            state.yawnUntil = nil
            effects.append(.resumeAmbient)
        }

        if state.session != nil, state.companion == nil {
            state.companion = .idle
        }
        reflowInvitation(&state, now: now)
    }

    /// Ends the post-break celebration. The leaf-carrying moment only makes
    /// sense while the pet is visible, awake and allowed to be expressive.
    private static func finishCompletion(
        _ state: inout PetSituation,
        effects: inout [PetEffect],
        now: Date
    ) {
        state.companion = state.session != nil ? .idle : nil
        state.completeEndsAt = nil
        if state.isQuietActive {
            // Quiet won the desk: settle with a yawn, then deep sleep. No leaf run.
            beginLifeYawn(&state, at: now)
            return
        }
        if !state.isHidden, !state.isReduceMotion, !state.promptsSuppressed {
            effects.append(.playCarry)
        }
    }

    private static func closeHiddenInvite(_ state: inout PetSituation, now: Date) {
        guard state.companion == .invite else { return }
        if !state.snoozeUsedThisSession {
            state.snoozeUsedThisSession = true
            state.snoozeUntil = now.addingTimeInterval(
                TimeInterval(state.policy.snoozeMinutes) * 60
            )
        }
        state.companion = state.session != nil ? .idle : nil
        state.lastInvitationClosedAt = now
        state.inviteShownAt = nil
    }

    private static func reflowInvitation(_ state: inout PetSituation, now: Date) {
        guard state.session != nil else { return }
        guard !state.promptsSuppressed else { return }
        guard state.companion == .idle || state.companion == .approach else { return }
        guard let due = state.invitationDueDate(),
              let approach = state.approachStartDate()
        else {
            return
        }

        if now >= due, canPresentInvite(state, now: now, bypassGap: false) {
            presentInvite(&state, at: now)
        } else if now >= approach {
            state.companion = .approach
        } else {
            state.companion = .idle
        }
    }

    private static func canPresentInvite(
        _ state: PetSituation,
        now: Date,
        bypassGap: Bool
    ) -> Bool {
        guard state.session != nil else { return false }
        guard !state.promptsSuppressed else { return false }
        guard !state.isMenuOpen else { return false }
        if let settled = state.dragSettledAt, settled > now { return false }
        switch state.companion {
        case .invite, .recover, .complete:
            return false
        default:
            break
        }
        if bypassGap { return true }
        guard let due = state.invitationDueDate() else { return false }
        return now >= due
    }

    private static func presentInvite(_ state: inout PetSituation, at now: Date) {
        state.companion = .invite
        state.inviteShownAt = state.isHidden ? now : nil
        state.isDozing = false
        state.isYawning = false
        state.yawnUntil = nil
        state.wasAwayLong = false
    }

    /// Clears blockers and ensures a session so Debug can open invite / recover / complete surfaces.
    private static func prepareDebugCompanionSurface(_ state: inout PetSituation, at now: Date) {
        state.isDoNotDisturb = false
        state.snoozeUntil = nil
        state.isDozing = false
        state.isYawning = false
        state.yawnUntil = nil
        state.wasAwayLong = false
        state.recoveryEndsAt = nil
        state.completeEndsAt = nil
        if state.session == nil {
            state.session = CompanionSession(startedAt: now)
            state.snoozeUsedThisSession = false
        }
    }

    private static func finish(
        _ state: PetSituation,
        old: PetSituation,
        now: Date,
        effects: [PetEffect]
    ) -> PetTransition {
        var result = effects
        guard !state.isSystemSleeping, !state.isScreenLocked else {
            return PetTransition(state: state, effects: result)
        }

        let oldPose = old.resolvedPose(at: now)
        let newPose = state.resolvedPose(at: now)
        if oldPose != newPose {
            result.append(.play(newPose))
        }

        let oldCard = old.isInviteCardVisible(at: now)
        let newCard = state.isInviteCardVisible(at: now)
        if oldCard != newCard {
            result.append(newCard ? .showInviteCard : .dismissInviteCard)
        }

        let oldPanel = old.isRecoveryPanelVisible(at: now)
        let newPanel = state.isRecoveryPanelVisible(at: now)
        if oldPanel != newPanel {
            result.append(newPanel ? .showRecoveryPanel : .hideRecoveryPanel)
        }

        return PetTransition(state: state, effects: result)
    }
}
