import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import JoeyPet

@MainActor
struct JoeyPetTests {
    @Test func restoredPositionFallsBackToMainScreen() {
        let screens = [PetScreenGeometry(
            identifier: "main",
            visibleFrame: PetPositionRect(minX: 0, minY: 0, width: 1440, height: 900),
            isMain: true
        )]
        let point = PetPositionGeometry.restore(nil, on: screens, windowSize: PetPositionPoint(x: 160, y: 160))
        #expect(point.x >= 0)
        #expect(point.y >= 0)
    }

    @Test func ambientDelayStaysWithinConfiguredBounds() {
        let configuration = AmbientBehaviorScheduler.Configuration(minimumDelay: 12, maximumDelay: 35)
        #expect(AmbientBehaviorScheduler.boundedDelay(1, configuration: configuration) == 12)
        #expect(AmbientBehaviorScheduler.boundedDelay(99, configuration: configuration) == 35)
    }

    @Test func appWindowBuildsWithV0Title() {
        let defaults = UserDefaults(suiteName: "JoeyPetTests")!
        defaults.removePersistentDomain(forName: "JoeyPetTests")
        let settings = AppSettings(defaults: defaults)

        let home = MainWindowController(
            settings: settings,
            onPrimaryAction: {}
        )
        #expect(home.window?.title == "Joey 的家")
        #expect(home.window?.contentView != nil)
        #expect(home.window?.minSize == NSSize(width: 880, height: 560))
    }

    @Test func settingsIsAnInWindowPage() {
        let navigation = NestNavigation()
        navigation.showReflection()
        navigation.openSettings()
        #expect(navigation.route == .settings)

        navigation.closeSettings()
        #expect(navigation.route == .reflection)

        navigation.toggleSettings()
        #expect(navigation.route == .settings)

        navigation.toggleSettings()
        #expect(navigation.route == .reflection)
    }

    @Test func desktopPetIsHiddenByDefault() {
        let defaults = UserDefaults(suiteName: "JoeyPetTestsDefaults")!
        defaults.removePersistentDomain(forName: "JoeyPetTestsDefaults")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.showsDesktopPet == false)
    }
}

// MARK: - Pet domain

private func testCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}

private func testDate(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int,
    _ minute: Int = 0
) -> Date {
    let calendar = testCalendar()
    return calendar.date(from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    ))!
}

@MainActor
struct PetDomainTests {
    @Test func quietWindowCrossesMidnight() {
        let calendar = testCalendar()
        let window = QuietWindow(startMinutes: 22 * 60, endMinutes: 8 * 60)

        #expect(window.isActive(at: testDate(2026, 11, 23, 23, 0), calendar: calendar))
        #expect(window.isActive(at: testDate(2026, 11, 24, 7, 59), calendar: calendar))
        #expect(!window.isActive(at: testDate(2026, 11, 24, 8, 0), calendar: calendar))
        #expect(!window.isActive(at: testDate(2026, 11, 23, 12, 0), calendar: calendar))

        let disabled = QuietWindow(startMinutes: 10 * 60, endMinutes: 10 * 60)
        #expect(!disabled.isActive(at: testDate(2026, 11, 23, 10, 0), calendar: calendar))
    }

    @Test func invitationPolicyUsesRhythmWithFortyFiveMinuteFloor() {
        let start = testDate(2026, 11, 23, 9, 0)
        let policy45 = InvitationPolicy(rhythmMinutes: 45)
        let policy90 = InvitationPolicy(rhythmMinutes: 90)
        let floor = InvitationPolicy(rhythmMinutes: 30)

        #expect(policy45.effectiveGapMinutes == 45)
        #expect(policy90.effectiveGapMinutes == 90)
        #expect(floor.effectiveGapMinutes == 45)
        #expect(policy45.nextDue(sessionStart: start, lastClosed: nil)
            == start.addingTimeInterval(45 * 60))

        let lastClosed = start.addingTimeInterval(10 * 60)
        #expect(policy45.nextDue(sessionStart: start, lastClosed: lastClosed)
            == lastClosed.addingTimeInterval(45 * 60))
    }

    @Test func priorityLadderOverridesPoseButKeepsSession() {
        let now = testDate(2026, 11, 23, 9, 0)
        var situation = PetSituation()
        situation.session = CompanionSession(startedAt: now)
        situation.companion = .idle
        situation.snoozeUntil = now.addingTimeInterval(10 * 60)
        situation.pauseUntil = now.addingTimeInterval(60 * 60)
        situation.isQuietActive = true
        situation.isHidden = true
        situation.isDragging = true

        #expect(situation.resolvedDesktop(at: now) == .dragging)
        situation.isDragging = false
        #expect(situation.resolvedDesktop(at: now) == .hidden)
        situation.isHidden = false
        #expect(situation.resolvedDesktop(at: now) == .quiet)
        situation.isQuietActive = false
        #expect(situation.resolvedDesktop(at: now) == .paused)
        situation.pauseUntil = nil
        #expect(situation.resolvedDesktop(at: now) == .snoozed)
        situation.snoozeUntil = nil
        #expect(situation.resolvedDesktop(at: now) == .companion)
        #expect(situation.session != nil)

        situation.session = nil
        situation.companion = nil
        #expect(situation.resolvedDesktop(at: now) == .alone)
    }

    @Test func companionFlowFromInviteToCompletion() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)

        let started = PetStateMachine.reduce(
            PetSituation(),
            event: .sessionStart,
            now: start,
            calendar: calendar
        )
        #expect(started.state.resolvedDesktop(at: start) == .companion)
        #expect(started.state.companion == .idle)
        #expect(started.state.resolvedPose(at: start) == .look)

        let approachTime = start.addingTimeInterval(40 * 60 + 1)
        let approached = PetStateMachine.reduce(
            started.state,
            event: .tick,
            now: approachTime,
            calendar: calendar
        )
        #expect(approached.state.companion == .approach)

        let due = start.addingTimeInterval(45 * 60)
        let invited = PetStateMachine.reduce(
            approached.state,
            event: .tick,
            now: due,
            calendar: calendar
        )
        #expect(invited.state.companion == .invite)
        #expect(invited.state.resolvedPose(at: due) == .sign)
        #expect(invited.effects.contains(.showInviteCard))

        let accepted = PetStateMachine.reduce(
            invited.state,
            event: .inviteAccepted,
            now: due,
            calendar: calendar
        )
        #expect(accepted.state.companion == .recover)
        #expect(accepted.state.resolvedPose(at: due) == .stretch)
        #expect(accepted.effects.contains(.dismissInviteCard))
        #expect(accepted.effects.contains(.showRecoveryPanel))

        let recoveryEnd = due.addingTimeInterval(30)
        let completed = PetStateMachine.reduce(
            accepted.state,
            event: .recoveryFinished,
            now: recoveryEnd,
            calendar: calendar
        )
        #expect(completed.state.companion == .complete)
        #expect(completed.state.resolvedPose(at: recoveryEnd) == .happy)
        #expect(completed.effects.contains(.completeRecovery))

        let idle = PetStateMachine.reduce(
            completed.state,
            event: .completeFinished,
            now: recoveryEnd.addingTimeInterval(2.6),
            calendar: calendar
        )
        #expect(idle.state.companion == .idle)
        #expect(idle.state.resolvedPose(at: recoveryEnd.addingTimeInterval(2.6)) == .look)
    }

    @Test func snoozeAllowsOneTenMinuteRetry() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        let due = start.addingTimeInterval(45 * 60)

        let started = PetStateMachine.reduce(
            PetSituation(),
            event: .sessionStart,
            now: start,
            calendar: calendar
        ).state
        let invited = PetStateMachine.reduce(
            started,
            event: .tick,
            now: due,
            calendar: calendar
        ).state
        let snoozed = PetStateMachine.reduce(
            invited,
            event: .snoozeRequested,
            now: due,
            calendar: calendar
        ).state

        #expect(snoozed.companion == .idle)
        #expect(snoozed.snoozeUntil == due.addingTimeInterval(10 * 60))
        #expect(snoozed.resolvedPose(at: due) == .sit)

        let retry = PetStateMachine.reduce(
            snoozed,
            event: .tick,
            now: due.addingTimeInterval(10 * 60),
            calendar: calendar
        )
        #expect(retry.state.companion == .invite)
        #expect(retry.state.resolvedPose(at: due.addingTimeInterval(10 * 60)) == .sign)

        let secondSnooze = PetStateMachine.reduce(
            retry.state,
            event: .snoozeRequested,
            now: due.addingTimeInterval(10 * 60),
            calendar: calendar
        ).state
        #expect(secondSnooze.companion == .idle)
        #expect(secondSnooze.snoozeUntil == nil)
        #expect(secondSnooze.snoozeUsedThisSession)
    }

    @Test func pauseKeepsSessionAndExpiresAfterSixtyMinutes() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)

        let started = PetStateMachine.reduce(
            PetSituation(),
            event: .sessionStart,
            now: start,
            calendar: calendar
        ).state
        let paused = PetStateMachine.reduce(
            started,
            event: .pauseRequested,
            now: start,
            calendar: calendar
        ).state
        #expect(paused.resolvedDesktop(at: start) == .paused)
        #expect(paused.resolvedPose(at: start) == .sit)
        #expect(paused.session != nil)

        let almost = start.addingTimeInterval(59 * 60)
        #expect(paused.resolvedDesktop(at: almost) == .paused)

        let expired = PetStateMachine.reduce(
            paused,
            event: .tick,
            now: start.addingTimeInterval(60 * 60),
            calendar: calendar
        ).state
        #expect(expired.pauseUntil == nil)
        #expect(expired.resolvedDesktop(at: start.addingTimeInterval(60 * 60)) == .companion)
        #expect(expired.companion == .invite)
        #expect(expired.resolvedPose(at: start.addingTimeInterval(60 * 60)) == .sign)
        #expect(expired.session != nil)
    }

    @Test func quietHoursClosesInviteAndSleeps() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 21, 0)
        let due = start.addingTimeInterval(45 * 60)

        let started = PetStateMachine.reduce(
            PetSituation(),
            event: .sessionStart,
            now: start,
            calendar: calendar
        ).state
        let invited = PetStateMachine.reduce(
            started,
            event: .tick,
            now: due,
            calendar: calendar
        ).state
        #expect(invited.companion == .invite)

        let quietTime = testDate(2026, 11, 23, 23, 0)
        let quiet = PetStateMachine.reduce(
            invited,
            event: .tick,
            now: quietTime,
            calendar: calendar
        )
        #expect(quiet.state.resolvedDesktop(at: quietTime) == .quiet)
        #expect(quiet.state.resolvedPose(at: quietTime) == .sleep)
        #expect(quiet.state.companion == .idle)
        #expect(quiet.state.session != nil)
        #expect(quiet.effects.contains(.dismissInviteCard))
    }

    @Test func quietHoursLetsRecoveryFinishBeforeSleeping() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 21, 0)
        let due = start.addingTimeInterval(45 * 60)

        let started = PetStateMachine.reduce(
            PetSituation(),
            event: .sessionStart,
            now: start,
            calendar: calendar
        ).state
        let invited = PetStateMachine.reduce(
            started,
            event: .tick,
            now: due,
            calendar: calendar
        ).state
        let recovering = PetStateMachine.reduce(
            invited,
            event: .inviteAccepted,
            now: due,
            calendar: calendar
        ).state

        let quietTime = testDate(2026, 11, 23, 23, 0)
        let completed = PetStateMachine.reduce(
            recovering,
            event: .tick,
            now: quietTime,
            calendar: calendar
        )
        #expect(completed.state.resolvedDesktop(at: quietTime) == .quiet)
        #expect(completed.state.companion == .complete)
        #expect(completed.state.resolvedPose(at: quietTime) == .happy)
        #expect(completed.effects.contains(.completeRecovery))

        let sleepTime = quietTime.addingTimeInterval(2.6)
        let sleeping = PetStateMachine.reduce(
            completed.state,
            event: .tick,
            now: sleepTime,
            calendar: calendar
        ).state
        #expect(sleeping.companion == .idle)
        #expect(sleeping.resolvedPose(at: sleepTime) == .sleep)
    }

    @Test func hiddenKeepsSessionAndHidesSurfaces() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        let due = start.addingTimeInterval(45 * 60)

        let started = PetStateMachine.reduce(
            PetSituation(),
            event: .sessionStart,
            now: start,
            calendar: calendar
        ).state
        let invited = PetStateMachine.reduce(
            started,
            event: .tick,
            now: due,
            calendar: calendar
        ).state
        let hidden = PetStateMachine.reduce(
            invited,
            event: .hideRequested,
            now: due,
            calendar: calendar
        ).state

        #expect(hidden.resolvedDesktop(at: due) == .hidden)
        #expect(hidden.companion == .idle)
        #expect(hidden.session != nil)
        #expect(!hidden.isInviteCardVisible(at: due))

        let shown = PetStateMachine.reduce(
            hidden,
            event: .showRequested,
            now: due.addingTimeInterval(1),
            calendar: calendar
        ).state
        #expect(shown.resolvedDesktop(at: due.addingTimeInterval(1)) == .companion)
        #expect(shown.session != nil)
    }

    @Test func presenceDozeYawnsOnReturn() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 23, 9, 0)

        let dozing = PetStateMachine.reduce(
            PetSituation(),
            event: .presenceIdle90,
            now: now,
            calendar: calendar
        ).state
        #expect(dozing.isDozing)
        #expect(dozing.resolvedPose(at: now) == .doze)

        let returned = PetStateMachine.reduce(
            dozing,
            event: .presenceReturned,
            now: now.addingTimeInterval(1),
            calendar: calendar
        ).state
        #expect(!returned.isDozing)
        #expect(returned.isYawning)
        #expect(returned.resolvedPose(at: now.addingTimeInterval(1)) == .yawn)

        let settled = PetStateMachine.reduce(
            returned,
            event: .tick,
            now: now.addingTimeInterval(3),
            calendar: calendar
        ).state
        #expect(!settled.isYawning)
        #expect(settled.resolvedPose(at: now.addingTimeInterval(3)) == .sit)
    }

    @Test func presenceIsIgnoredDuringCompanion() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)

        let started = PetStateMachine.reduce(
            PetSituation(),
            event: .sessionStart,
            now: start,
            calendar: calendar
        ).state
        let idle = PetStateMachine.reduce(
            started,
            event: .presenceIdle90,
            now: start.addingTimeInterval(90),
            calendar: calendar
        ).state
        #expect(!idle.isDozing)
        #expect(idle.resolvedPose(at: start.addingTimeInterval(90)) == .look)
    }

    @Test func systemSleepFreezesInvitationProgression() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        let due = start.addingTimeInterval(45 * 60)

        let started = PetStateMachine.reduce(
            PetSituation(),
            event: .sessionStart,
            now: start,
            calendar: calendar
        ).state
        let sleeping = PetStateMachine.reduce(
            started,
            event: .systemSleep,
            now: start,
            calendar: calendar
        )
        #expect(sleeping.state.isSystemSleeping)
        #expect(sleeping.effects.contains(.freeze))

        let ticked = PetStateMachine.reduce(
            sleeping.state,
            event: .tick,
            now: due,
            calendar: calendar
        ).state
        #expect(ticked.companion == .idle)

        let awake = PetStateMachine.reduce(
            ticked,
            event: .systemWake,
            now: due.addingTimeInterval(1),
            calendar: calendar
        )
        #expect(!awake.state.isSystemSleeping)
        #expect(awake.effects.contains(.resume))
    }

    @Test func configurationChangeMovesApproachWindow() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        let oldApproach = start.addingTimeInterval(40 * 60 + 1)

        let started = PetStateMachine.reduce(
            PetSituation(),
            event: .sessionStart,
            now: start,
            calendar: calendar
        ).state
        let approached = PetStateMachine.reduce(
            started,
            event: .tick,
            now: oldApproach,
            calendar: calendar
        ).state
        #expect(approached.companion == .approach)

        let reconfigured = PetStateMachine.reduce(
            approached,
            event: .configurationChanged(quietWindow: QuietWindow(), rhythmMinutes: 90),
            now: oldApproach,
            calendar: calendar
        ).state
        #expect(reconfigured.companion == .idle)
        #expect(reconfigured.policy.effectiveGapMinutes == 90)
    }

    @Test func persistenceRoundTripsAndNormalizesDays() {
        let suite = "JoeyPetTestsDomain"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = UserDefaultsPetSessionStore(defaults: defaults)
        let now = testDate(2026, 11, 23, 9, 0)
        let calendar = testCalendar()

        var state = PetPersistedState.empty(now: now, calendar: calendar)
        state.pauseUntil = now.addingTimeInterval(60 * 60)
        state.lastInvitationClosedAt = now.addingTimeInterval(-45 * 60)
        state.todayKey = "1999-01-01"
        state.todayCompanionshipSeconds = 999
        state.todayBreaks = 5
        state.weekStartKey = "1999-01-01"
        state.weekBreakCounts = [9, 9, 9, 9, 9, 9, 9]
        state.quietWindow = QuietWindow(startMinutes: 23 * 60, endMinutes: 7 * 60)
        state.rhythmMinutes = 60
        state.showsDesktopPet = true
        store.save(state)

        let loaded = store.load(now: now, calendar: calendar)
        #expect(loaded.pauseUntil == state.pauseUntil)
        #expect(loaded.lastInvitationClosedAt == state.lastInvitationClosedAt)
        #expect(loaded.quietWindow == state.quietWindow)
        #expect(loaded.rhythmMinutes == 60)
        #expect(loaded.showsDesktopPet)
        #expect(loaded.todayKey == PetDayKey.dayKey(for: now, calendar: calendar))
        #expect(loaded.todayCompanionshipSeconds == 0)
        #expect(loaded.todayBreaks == 0)
        #expect(loaded.weekStartKey == PetDayKey.weekStartKey(for: now, calendar: calendar))
        #expect(loaded.weekBreakCounts == Array(repeating: 0, count: 7))
    }

    @Test func weekIndexStartsOnMonday() {
        let calendar = testCalendar()
        #expect(PetDayKey.weekdayIndex(for: testDate(2026, 11, 23, 9, 0), calendar: calendar) == 0)
        #expect(PetDayKey.weekdayIndex(for: testDate(2026, 11, 29, 9, 0), calendar: calendar) == 6)
    }
}

