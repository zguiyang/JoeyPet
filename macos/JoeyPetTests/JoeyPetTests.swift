import AppKit
import CoreGraphics
import Foundation
import SpriteKit
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
        let point = PetPositionGeometry.restore(nil, on: screens, windowSize: PetPositionPoint(x: 168, y: 210))
        #expect(point.x == 1440 - 168 - 40)
        #expect(point.y == 92)
    }

    @Test func restoredPositionFallsBackToTheChosenCorner() {
        let screens = [PetScreenGeometry(
            identifier: "main",
            visibleFrame: PetPositionRect(minX: 0, minY: 0, width: 1440, height: 900),
            isMain: true
        )]
        let point = PetPositionGeometry.restore(
            nil,
            on: screens,
            windowSize: PetPositionPoint(x: 168, y: 210),
            corner: .bottomLeft
        )
        #expect(point.x == 40)
        #expect(point.y == 92)
    }

    @Test func panelUsesTheDocumentedSize() {
        #expect(PetPanelController.panelSize == NSSize(width: 168, height: 210))
    }

    @Test func restoredPositionKeepsTheDragMargin() {
        let screens = [PetScreenGeometry(
            identifier: "main",
            visibleFrame: PetPositionRect(minX: 0, minY: 0, width: 1440, height: 900),
            isMain: true
        )]
        let saved = PetPositionRecord(
            screenIdentifier: nil,
            absoluteOrigin: PetPositionPoint(x: 0, y: 0),
            normalizedOrigin: PetPositionPoint(x: 0, y: 0),
            savedVisibleFrame: PetPositionRect(minX: 0, minY: 0, width: 1440, height: 900)
        )

        let point = PetPositionGeometry.restore(
            saved,
            on: screens,
            windowSize: PetPositionPoint(x: 168, y: 210)
        )
        #expect(point == PetPositionPoint(x: 8, y: 8))
    }

    @Test func draggingClampsToTheEightPointMargin() {
        let visible = PetPositionRect(minX: 0, minY: 0, width: 1440, height: 900)

        let topLeft = PetPanelGeometry.clampedOrigin(
            PetPositionPoint(x: -500, y: 5000),
            in: visible,
            windowSize: PetPanelGeometry.defaultSize
        )
        #expect(topLeft.x == 8)
        #expect(topLeft.y == 900 - 210 - 8)
    }

    @Test func appWindowBuildsWithV0Title() {
        let testDefaults = TestDefaults("JoeyPetTests")
        defer { testDefaults.remove() }
        let settings = AppSettings(defaults: testDefaults.defaults)

        let home = MainWindowController(
            settings: settings,
            status: CompanionStatus(),
            onPrimaryAction: {},
            onGreetPet: {}
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

    @Test func appearanceSwitchUpdatesThemeAndNotifies() {
        let testDefaults = TestDefaults("JoeyPetTestsAppearance")
        defer { testDefaults.remove() }
        let settings = AppSettings(defaults: testDefaults.defaults)
        var notified: JoeyAppearance?
        settings.onAppearanceChanged = { notified = $0 }

        settings.appearance = .dusk

        #expect(notified == .dusk)
        #expect(settings.appearance == .dusk)
        #expect(JoeyAppearance.light.nsAppearance?.name == .aqua)
        #expect(JoeyAppearance.dusk.nsAppearance?.name == .darkAqua)
    }

    @Test func desktopPetIsHiddenByDefault() {
        let testDefaults = TestDefaults("JoeyPetTestsDefaults")
        defer { testDefaults.remove() }
        let settings = AppSettings(defaults: testDefaults.defaults)
        #expect(settings.showsDesktopPet == false)
    }

    @Test func petCornerDefaultsToBottomRightAndPersists() {
        let testDefaults = TestDefaults("JoeyPetTestsCorner")
        defer { testDefaults.remove() }
        let settings = AppSettings(defaults: testDefaults.defaults)
        #expect(settings.petCorner == .bottomRight)

        var notified: PetCorner?
        settings.onPetCornerChanged = { notified = $0 }
        settings.petCorner = .bottomLeft
        #expect(notified == .bottomLeft)

        let reloaded = AppSettings(defaults: testDefaults.defaults)
        #expect(reloaded.petCorner == .bottomLeft)
    }

    @Test func soundSelectionDefaultsAndPersists() {
        let testDefaults = TestDefaults("JoeyPetTestsSound")
        defer { testDefaults.remove() }
        let settings = AppSettings(defaults: testDefaults.defaults)
        #expect(settings.ambientSoundID == JoeyAudioCatalog.noneID)
        #expect(settings.cueSoundID == AppSettings.defaultCueSoundID)

        var notified: (String, String)?
        settings.onSoundSelectionChanged = { ambient, cue in
            notified = (ambient, cue)
        }
        settings.ambientSoundID = "rain_soft_lynks"
        settings.cueSoundID = JoeyAudioCatalog.noneID
        #expect(notified?.0 == "rain_soft_lynks")
        #expect(notified?.1 == JoeyAudioCatalog.noneID)

        let reloaded = AppSettings(defaults: testDefaults.defaults)
        #expect(reloaded.ambientSoundID == "rain_soft_lynks")
        #expect(reloaded.cueSoundID == JoeyAudioCatalog.noneID)
    }

    @Test func audioMutePolicySilencesOnDoNotDisturbOrQuiet() {
        #expect(
            JoeyAudioMutePolicy.shouldSilence(isDoNotDisturb: false, isQuietActive: false)
                == false
        )
        #expect(JoeyAudioMutePolicy.shouldSilence(isDoNotDisturb: true, isQuietActive: false))
        #expect(JoeyAudioMutePolicy.shouldSilence(isDoNotDisturb: false, isQuietActive: true))
        #expect(JoeyAudioMutePolicy.shouldSilence(isDoNotDisturb: true, isQuietActive: true))
    }

    @Test func audioCatalogLoadsBundledTracksAndSanitizes() {
        let catalog = JoeyAudioCatalog.load()
        #expect(!catalog.ambient.isEmpty)
        #expect(!catalog.cues.isEmpty)
        #expect(catalog.ambient.contains(where: { $0.id == "rain_soft_lynks" }))
        #expect(catalog.cue(id: "cue_ceramic_cups") != nil)
        #expect(catalog.sanitizedAmbientID("missing_track") == JoeyAudioCatalog.noneID)
        #expect(catalog.sanitizedCueID(JoeyAudioCatalog.noneID) == JoeyAudioCatalog.noneID)
        #expect(catalog.attributionTracks.contains(where: { $0.id == "wind_autumn_nicktayloe" }))
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

/// A throwaway persistent domain for settings tests.
///
/// `removePersistentDomain` clears the keys but leaves the plist on disk, so
/// cleanup also removes the file to keep `~/Library/Preferences` free of test residue.
private struct TestDefaults {
    let defaults: UserDefaults
    private let suiteName: String

    init(_ suiteName: String) {
        self.suiteName = suiteName
        defaults = UserDefaults(suiteName: suiteName)!
        remove()
    }

    func remove() {
        defaults.removePersistentDomain(forName: suiteName)
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(suiteName).plist")
        try? FileManager.default.removeItem(at: url)
    }
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
        situation.isDoNotDisturb = true
        situation.isQuietActive = true
        situation.isHidden = true
        situation.isDragging = true

        #expect(situation.resolvedDesktop(at: now) == .dragging)
        situation.isDragging = false
        #expect(situation.resolvedDesktop(at: now) == .hidden)
        situation.isHidden = false
        #expect(situation.resolvedDesktop(at: now) == .quiet)
        situation.isQuietActive = false
        #expect(situation.resolvedDesktop(at: now) == .doNotDisturb)
        situation.isDoNotDisturb = false
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
        #expect(invited.state.resolvedPose(at: due) == .look)
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
        #expect(retry.state.resolvedPose(at: due.addingTimeInterval(10 * 60)) == .look)

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

    @Test func doNotDisturbKeepsSessionAndSuppressesInvitations() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        let due = start.addingTimeInterval(45 * 60)

        let started = PetStateMachine.reduce(
            PetSituation(),
            event: .sessionStart,
            now: start,
            calendar: calendar
        ).state
        let quiet = PetStateMachine.reduce(
            started,
            event: .doNotDisturbChanged(true),
            now: start,
            calendar: calendar
        ).state
        #expect(quiet.isDoNotDisturb)
        #expect(quiet.resolvedDesktop(at: start) == .doNotDisturb)
        #expect(quiet.resolvedPose(at: start) == .doze)
        #expect(quiet.session != nil)

        let still = PetStateMachine.reduce(
            quiet,
            event: .tick,
            now: due,
            calendar: calendar
        ).state
        #expect(still.companion == .idle)
        #expect(!still.isInviteCardVisible(at: due))

        let resumed = PetStateMachine.reduce(
            still,
            event: .doNotDisturbChanged(false),
            now: due,
            calendar: calendar
        ).state
        #expect(!resumed.isDoNotDisturb)
        #expect(resumed.companion == .invite)
        #expect(resumed.session != nil)
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

    @Test func hiddenKeepsSessionAndStillInvites() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        let due = start.addingTimeInterval(45 * 60)

        let started = PetStateMachine.reduce(
            PetSituation(),
            event: .sessionStart,
            now: start,
            calendar: calendar
        ).state
        let hidden = PetStateMachine.reduce(
            started,
            event: .hideRequested,
            now: start,
            calendar: calendar
        ).state
        #expect(hidden.resolvedDesktop(at: start) == .hidden)
        #expect(hidden.session != nil)
        #expect(!hidden.shouldShowPanel(at: start))

        let invited = PetStateMachine.reduce(
            hidden,
            event: .tick,
            now: due,
            calendar: calendar
        ).state
        #expect(invited.companion == .invite)
        #expect(invited.isInviteCardVisible(at: due))
        #expect(invited.resolvedDesktop(at: due) == .companion)
        #expect(invited.shouldShowPanel(at: due))

        // An ignored hidden invitation slips away after one minute and is
        // treated as "later" once.
        let closed = PetStateMachine.reduce(
            invited,
            event: .tick,
            now: due.addingTimeInterval(60),
            calendar: calendar
        ).state
        #expect(closed.companion == .idle)
        #expect(closed.snoozeUntil == due.addingTimeInterval(60 + 10 * 60))
        #expect(!closed.shouldShowPanel(at: due.addingTimeInterval(60)))
        #expect(closed.session != nil)

        let shown = PetStateMachine.reduce(
            closed,
            event: .showRequested,
            now: due.addingTimeInterval(61),
            calendar: calendar
        ).state
        #expect(shown.resolvedDesktop(at: due.addingTimeInterval(61)) == .snoozed)
        #expect(shown.session != nil)
    }

    @Test func hiddenInvitationCompletesAndReturnsToHiding() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        let due = start.addingTimeInterval(45 * 60)

        let started = PetStateMachine.reduce(
            PetSituation(),
            event: .sessionStart,
            now: start,
            calendar: calendar
        ).state
        let hidden = PetStateMachine.reduce(
            started,
            event: .hideRequested,
            now: start,
            calendar: calendar
        ).state
        let invited = PetStateMachine.reduce(
            hidden,
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
        #expect(recovering.companion == .recover)
        #expect(recovering.isRecoveryPanelVisible(at: due))
        #expect(recovering.shouldShowPanel(at: due))

        let completed = PetStateMachine.reduce(
            recovering,
            event: .tick,
            now: due.addingTimeInterval(30),
            calendar: calendar
        ).state
        #expect(completed.companion == .complete)
        #expect(completed.shouldShowPanel(at: due.addingTimeInterval(30)))

        let settledAt = due.addingTimeInterval(32.6)
        let settled = PetStateMachine.reduce(
            completed,
            event: .tick,
            now: settledAt,
            calendar: calendar
        ).state
        #expect(settled.companion == .idle)
        #expect(!settled.shouldShowPanel(at: settledAt))
        #expect(settled.session != nil)
    }

    @Test func hidingDuringInvitationClosesIt() {
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
        #expect(hidden.companion == .idle)
        #expect(!hidden.isInviteCardVisible(at: due))
        #expect(!hidden.shouldShowPanel(at: due))
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

    @Test func completedBreakCarriesALeafHome() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        var situation = PetSituation()
        situation.session = CompanionSession(startedAt: start)
        situation.companion = .complete
        situation.completeEndsAt = start.addingTimeInterval(2.6)

        let finished = PetStateMachine.reduce(
            situation,
            event: .tick,
            now: start.addingTimeInterval(2.6),
            calendar: calendar
        )
        #expect(finished.state.companion == .idle)
        #expect(finished.effects.contains(.playCarry))

        var quiet = situation
        quiet.quietWindow = QuietWindow(startMinutes: 8 * 60, endMinutes: 10 * 60)
        let quietFinished = PetStateMachine.reduce(
            quiet,
            event: .tick,
            now: start.addingTimeInterval(2.6),
            calendar: calendar
        )
        #expect(!quietFinished.effects.contains(.playCarry))

        var reduced = situation
        reduced.isReduceMotion = true
        let reducedFinished = PetStateMachine.reduce(
            reduced,
            event: .tick,
            now: start.addingTimeInterval(2.6),
            calendar: calendar
        )
        #expect(!reducedFinished.effects.contains(.playCarry))
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
        let testDefaults = TestDefaults("JoeyPetTestsDomain")
        defer { testDefaults.remove() }

        let store = UserDefaultsPetSessionStore(defaults: testDefaults.defaults)
        let now = testDate(2026, 11, 23, 9, 0)
        let calendar = testCalendar()

        var state = PetPersistedState.empty(now: now, calendar: calendar)
        state.isDoNotDisturb = true
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
        #expect(loaded.isDoNotDisturb)
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

    @Test func sessionSurfacesFollowInvitationAndRecovery() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        let due = start.addingTimeInterval(45 * 60)

        let started = PetStateMachine.reduce(
            PetSituation(),
            event: .sessionStart,
            now: start,
            calendar: calendar
        ).state

        let alonePresentation = SessionSurfacePresentation(
            situation: PetSituation(),
            previous: nil,
            now: start
        )
        #expect(!alonePresentation.showsCompanionChip)
        #expect(!alonePresentation.showsInvitation)

        let idlePresentation = SessionSurfacePresentation(
            situation: started,
            previous: nil,
            now: start
        )
        #expect(idlePresentation.showsCompanionChip)
        #expect(!idlePresentation.showsInvitation)
        #expect(!idlePresentation.showsRecovery)

        let invited = PetStateMachine.reduce(
            started,
            event: .tick,
            now: due,
            calendar: calendar
        ).state
        let invitePresentation = SessionSurfacePresentation(
            situation: invited,
            previous: started,
            now: due
        )
        #expect(invitePresentation.showsInvitation)
        #expect(!invitePresentation.showsRecovery)

        let recovering = PetStateMachine.reduce(
            invited,
            event: .inviteAccepted,
            now: due,
            calendar: calendar
        ).state
        let recoveryPresentation = SessionSurfacePresentation(
            situation: recovering,
            previous: invited,
            now: due
        )
        #expect(!recoveryPresentation.showsInvitation)
        #expect(recoveryPresentation.showsRecovery)
        #expect(recoveryPresentation.recoveryEndsAt == due.addingTimeInterval(30))
        #expect(!recoveryPresentation.newlyCompleted)

        let completed = PetStateMachine.reduce(
            recovering,
            event: .recoveryFinished,
            now: due.addingTimeInterval(30),
            calendar: calendar
        ).state
        let completedPresentation = SessionSurfacePresentation(
            situation: completed,
            previous: recovering,
            now: due.addingTimeInterval(30)
        )
        #expect(!completedPresentation.showsRecovery)
        #expect(completedPresentation.newlyCompleted)

        let settled = SessionSurfacePresentation(
            situation: completed,
            previous: completed,
            now: due.addingTimeInterval(31)
        )
        #expect(!settled.newlyCompleted)
    }

    @Test func doNotDisturbCancelsInvitationAndResumeKeepsGap() {
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
        #expect(invited.companion == .invite)

        let quiet = PetStateMachine.reduce(
            invited,
            event: .doNotDisturbChanged(true),
            now: due,
            calendar: calendar
        ).state
        #expect(quiet.isDoNotDisturb)
        #expect(quiet.companion == .idle)
        #expect(!quiet.isInviteCardVisible(at: due))

        let resumed = PetStateMachine.reduce(
            quiet,
            event: .doNotDisturbChanged(false),
            now: due.addingTimeInterval(60),
            calendar: calendar
        ).state
        #expect(!resumed.isDoNotDisturb)
        #expect(resumed.companion == .idle)
        #expect(resumed.invitationDueDate() == due.addingTimeInterval(45 * 60))
    }

    @Test func companionChipTextUsesMinutesAndSeconds() {
        let start = testDate(2026, 11, 23, 9, 0)
        #expect(CompanionTimeText.elapsedText(from: start, to: start) == "00:00")
        #expect(
            CompanionTimeText.elapsedText(
                from: start,
                to: start.addingTimeInterval(45 * 60 + 7)
            ) == "45:07"
        )
        #expect(
            CompanionTimeText.elapsedText(
                from: start,
                to: start.addingTimeInterval(2 * 60 * 60 + 3 * 60 + 9)
            ) == "123:09"
        )
        #expect(
            CompanionTimeText.elapsedText(
                from: start,
                to: start.addingTimeInterval(-5)
            ) == "00:00"
        )
    }
}

// MARK: - Layered rendering

private var joeyManifestURL: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("macos/JoeyPet/Resources/Pets/Joey/joey_manifest.json")
}

private var joeyResourceRootURL: URL {
    joeyManifestURL.deletingLastPathComponent()
}

@MainActor
struct JoeyManifestTests {
    @Test func manifestMatchesDomainVocabulary() throws {
        let manifest = try JoeyManifest.load(from: joeyManifestURL)
        let issues = JoeyManifestValidator.issues(in: manifest)
        #expect(issues.isEmpty, "\(issues)")

        #expect(manifest.schemaVersion == "0.1")
        #expect(manifest.poses.count == 12)
        #expect(manifest.states.count == 7)
        #expect(manifest.substates.count == 5)
        #expect(manifest.ambient.count == 8)
        #expect(manifest.transitions.count == 12)
        #expect(manifest.sizes.first(where: { $0.isDefault == true })?.w == 168)
        #expect(manifest.render?.layerOrder.count == 8)
        #expect(manifest.render?.poseLayers.count == 12)
        #expect(manifest.render?.poseLayers["wave"]?.frontArm == "arm.frontWave")
    }
}

@MainActor
struct JoeyRenderTests {
    @Test func manifestDeclaresPosePivots() throws {
        let manifest = try JoeyManifest.load(from: joeyManifestURL)
        #expect(manifest.render?.poseLayers["look"]?.pivot == [160, 330])
        #expect(manifest.render?.poseLayers["doze"]?.pivot == [160, 344])
        #expect(manifest.render?.poseLayers["yawn"]?.pivot == [160, 334])
        #expect(manifest.render?.poseLayers["step"] == nil)
    }

    @Test func everyPoseAndLayerResolvesToAPng() throws {
        let package = try JoeyAssetPackage.load(resourceRoot: joeyResourceRootURL, scale: .x1)

        for pose in PetPose.allCases {
            let layers = try #require(
                package.manifest.render?.poseLayers[pose.rawValue],
                "missing layers for \(pose.rawValue)"
            )
            #expect(package.poseTexture(poseID: pose.rawValue) != nil, "missing pose \(pose.rawValue)")

            let assetIDs = [
                layers.shadow, layers.tail, layers.body, layers.ears,
                layers.backArm, layers.face, layers.frontArm, layers.prop
            ].compactMap { $0 }

            for assetID in assetIDs {
                #expect(
                    package.layerTexture(assetID: assetID) != nil,
                    "missing \(assetID) for \(pose.rawValue)"
                )
            }
        }

        for frame in [2, 3] {
            #expect(package.layerTexture(assetID: "face.calm.blink\(frame)") != nil)
        }
    }

    @Test func layerTextureMatchesLogicalCanvas() throws {
        let package = try JoeyAssetPackage.load(resourceRoot: joeyResourceRootURL, scale: .x1)
        let texture = try #require(package.layerTexture(assetID: "body.default"))
        #expect(texture.size() == CGSize(width: 320, height: 400))
    }

    @Test func desktopSceneFitsTheCurrentPanel() throws {
        let package = try JoeyAssetPackage.load(resourceRoot: joeyResourceRootURL, scale: .x1)
        let smallPanel = JoeyDesktopScene(
            size: CGSize(width: 160, height: 160),
            package: package
        )
        let smallFit = min(160.0 / 168.0, 160.0 / 210.0)
        #expect(abs(smallPanel.fittedScale - CGFloat(168.0 / 320.0 * smallFit)) < 0.0001)

        let documentedPanel = JoeyDesktopScene(
            size: CGSize(width: 168, height: 210),
            package: package
        )
        #expect(abs(documentedPanel.fittedScale - CGFloat(168.0 / 320.0)) < 0.0001)
    }

    @Test func characterAppliesPoseAndSize() throws {
        let package = try JoeyAssetPackage.load(resourceRoot: joeyResourceRootURL, scale: .x1)
        let character = JoeyCharacterNode(package: package, sizeID: "m", reduceMotion: true)
        #expect(abs(character.xScale - 168.0 / 320.0) < 0.0001)

        character.applyPose("sit")
        #expect(character.poseID == "sit")
        #expect(character.isLayerVisible("body"))
        #expect(character.isLayerVisible("ears"))
        #expect(character.isLayerVisible("tail"))
        #expect(character.isLayerVisible("face"))
        character.applyPose("look")
        #expect(character.poseID == "look")
        character.applyPose("sleep")
        #expect(character.poseID == "sleep")

        character.applySize(id: "l")
        #expect(character.sizeID == "l")
        #expect(abs(character.xScale - 216.0 / 320.0) < 0.0001)
    }
}

// MARK: - Runtime

@MainActor
private final class TestPoseRenderer: PetPoseRendering {
    let skScene = SKScene(size: CGSize(width: 160, height: 160))
    private(set) var shownPoses: [PetPose] = []

    func show(pose: PetPose) {
        shownPoses.append(pose)
    }

    func setReduceMotion(_ enabled: Bool) {}
}

@MainActor
private final class TestSessionStore: PetSessionStoring {
    private(set) var state: PetPersistedState

    init(_ state: PetPersistedState) {
        self.state = state
    }

    func load(now: Date, calendar: Calendar) -> PetPersistedState {
        state.normalized(now: now, calendar: calendar)
    }

    func save(_ state: PetPersistedState) {
        self.state = state
    }
}

@MainActor
struct PetRuntimeTests {
    private func makePersisted(now: Date, calendar: Calendar) -> PetPersistedState {
        var state = PetPersistedState.empty(now: now, calendar: calendar)
        state.showsDesktopPet = true
        return state
    }

    private func makeRuntime(
        now: Date,
        calendar: Calendar,
        persisted: PetPersistedState? = nil
    ) -> (PetRuntime, TestPoseRenderer, TestSessionStore) {
        let store = TestSessionStore(persisted ?? makePersisted(now: now, calendar: calendar))
        let renderer = TestPoseRenderer()
        let runtime = PetRuntime(
            renderer: renderer,
            store: store,
            now: { now },
            calendar: calendar
        )
        return (runtime, renderer, store)
    }

    @Test func runtimeStartsAloneAndRendersSit() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 23, 9, 0)
        let (runtime, renderer, _) = makeRuntime(now: now, calendar: calendar)

        #expect(runtime.situation.resolvedDesktop(at: now) == .alone)
        #expect(runtime.renderedPose == .sit)
        #expect(renderer.shownPoses == [.sit])
    }

    @Test func runtimeRunsInvitationThroughTicks() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        var current = start
        let store = TestSessionStore(makePersisted(now: start, calendar: calendar))
        let renderer = TestPoseRenderer()
        let runtime = PetRuntime(
            renderer: renderer,
            store: store,
            now: { current },
            calendar: calendar
        )

        runtime.startSession()
        #expect(runtime.situation.companion == .idle)
        #expect(runtime.renderedPose == .look)

        current = start.addingTimeInterval(40 * 60 + 1)
        runtime.send(.tick)
        #expect(runtime.situation.companion == .approach)

        current = start.addingTimeInterval(45 * 60)
        runtime.send(.tick)
        #expect(runtime.situation.companion == .invite)
        #expect(runtime.renderedPose == .look)
        #expect(runtime.situation.isInviteCardVisible(at: current))
    }

    @Test func runtimePersistsInvitationClosure() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        var current = start
        let store = TestSessionStore(makePersisted(now: start, calendar: calendar))
        let runtime = PetRuntime(
            renderer: TestPoseRenderer(),
            store: store,
            now: { current },
            calendar: calendar
        )

        runtime.startSession()
        current = start.addingTimeInterval(45 * 60)
        runtime.send(.tick)
        runtime.send(.inviteDismissed)

        #expect(runtime.situation.companion == .idle)
        #expect(store.state.lastInvitationClosedAt == current)
        #expect(runtime.situation.invitationDueDate() == current.addingTimeInterval(45 * 60))
    }

    @Test func runtimeRecordsCompletedBreak() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        var current = start
        let store = TestSessionStore(makePersisted(now: start, calendar: calendar))
        let runtime = PetRuntime(
            renderer: TestPoseRenderer(),
            store: store,
            now: { current },
            calendar: calendar
        )

        runtime.startSession()
        current = start.addingTimeInterval(45 * 60)
        runtime.send(.tick)
        runtime.send(.inviteAccepted)

        current = start.addingTimeInterval(45 * 60 + 30)
        runtime.send(.tick)

        #expect(runtime.situation.companion == .complete)
        #expect(store.state.todayBreaks == 1)
        #expect(runtime.summary.todayBreaks == 1)
        let index = PetDayKey.weekdayIndex(for: current, calendar: calendar)
        #expect(store.state.weekBreakCounts[index] == 1)
    }

    @Test func runtimePersistsVisibility() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 23, 9, 0)
        let (runtime, _, store) = makeRuntime(now: now, calendar: calendar)

        runtime.setVisible(false)
        #expect(runtime.situation.isHidden)
        #expect(store.state.showsDesktopPet == false)

        runtime.setVisible(true)
        #expect(!runtime.situation.isHidden)
        #expect(store.state.showsDesktopPet == true)
    }

    @Test func runtimeAppliesDoNotDisturb() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        let (runtime, _, store) = makeRuntime(now: start, calendar: calendar)

        runtime.startSession()
        runtime.setDoNotDisturb(true)

        #expect(runtime.situation.isDoNotDisturb)
        #expect(runtime.situation.resolvedDesktop(at: start) == .doNotDisturb)
        #expect(store.state.isDoNotDisturb)

        runtime.setDoNotDisturb(false)
        #expect(!runtime.situation.isDoNotDisturb)
        #expect(!store.state.isDoNotDisturb)
    }

    @Test func runtimeRestoresDoNotDisturb() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        var persisted = makePersisted(now: start, calendar: calendar)
        persisted.isDoNotDisturb = true
        let store = TestSessionStore(persisted)
        let runtime = PetRuntime(
            renderer: TestPoseRenderer(),
            store: store,
            now: { start },
            calendar: calendar
        )
        #expect(runtime.situation.isDoNotDisturb)
        #expect(runtime.situation.resolvedDesktop(at: start) == .doNotDisturb)
        #expect(runtime.renderedPose == .doze)

        runtime.setDoNotDisturb(false)
        #expect(!runtime.situation.isDoNotDisturb)
        #expect(runtime.situation.resolvedDesktop(at: start) == .alone)
        #expect(!store.state.isDoNotDisturb)
    }

    @Test func runtimeSchedulesTicksOnlyWhenWorkRemains() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        var persisted = makePersisted(now: start, calendar: calendar)
        persisted.quietWindow = QuietWindow(startMinutes: 0, endMinutes: 0)
        let runtime = PetRuntime(
            renderer: TestPoseRenderer(),
            store: TestSessionStore(persisted),
            now: { start },
            calendar: calendar
        )

        #expect(runtime.nextWakeDate(after: start) == nil)

        runtime.startSession()
        #expect(runtime.nextWakeDate(after: start) != nil)

        runtime.send(.systemSleep)
        #expect(runtime.nextWakeDate(after: start) == nil)

        runtime.send(.systemWake)
        #expect(runtime.nextWakeDate(after: start) != nil)
    }

    @Test func presenceTrackerReportsEachThresholdOnce() {
        var tracker = PetPresenceTracker()
        #expect(tracker.update(idleSeconds: 89) == nil)
        #expect(tracker.update(idleSeconds: 90) == .presenceIdle90)
        #expect(tracker.update(idleSeconds: 120) == nil)
        #expect(tracker.update(idleSeconds: 30 * 60) == .presenceAway30)
        #expect(tracker.update(idleSeconds: 30 * 60 + 1) == nil)
        #expect(tracker.update(idleSeconds: 0.5) == .presenceReturned)
        #expect(tracker.update(idleSeconds: 3) == nil)
        #expect(tracker.update(idleSeconds: nil) == nil)
    }

    @Test func runtimeReportsDragAndMenuSituations() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 23, 9, 0)
        let (runtime, renderer, _) = makeRuntime(now: now, calendar: calendar)

        var seen: [DesktopState] = []
        runtime.onSituationChanged = { situation in
            seen.append(situation.resolvedDesktop(at: now))
        }

        runtime.send(.menuOpened)
        runtime.send(.dragBegan)
        #expect(runtime.renderedPose == .look)
        runtime.send(.dragEnded)
        runtime.send(.menuClosed)

        #expect(seen == [.alone, .dragging, .alone, .alone])
        #expect(renderer.shownPoses.contains(.look))
    }

    @Test func runtimeCarriesLeafAfterBreak() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        var current = start
        let runtime = PetRuntime(
            renderer: TestPoseRenderer(),
            store: TestSessionStore(makePersisted(now: start, calendar: calendar)),
            now: { current },
            calendar: calendar
        )

        runtime.startSession()
        current = start.addingTimeInterval(45 * 60)
        runtime.send(.tick)
        runtime.send(.inviteAccepted)

        current = start.addingTimeInterval(45 * 60 + 30)
        runtime.send(.tick)
        #expect(runtime.situation.companion == .complete)

        current = start.addingTimeInterval(45 * 60 + 32.6)
        runtime.send(.tick)
        #expect(runtime.renderedPose == .carry)
        #expect(runtime.currentTransientBehavior == .carrying)
    }

    @Test func greetingPlaysAndNotifiesTheNestMirror() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 23, 9, 0)
        let (runtime, renderer, _) = makeRuntime(now: now, calendar: calendar)

        var mirrored: [PetPose] = []
        runtime.onRenderedPoseChanged = { mirrored.append($0) }

        #expect(runtime.perform(.greeting))
        #expect(runtime.renderedPose == .wave)
        #expect(runtime.currentTransientBehavior == .greeting)
        #expect(mirrored == [.wave])
        #expect(renderer.shownPoses.last == .wave)
        #expect(PetTransientBehavior.greeting.sessionDuration == 2.8)
    }

    @Test func greetingStillPlaysWhileTheDesktopPetIsHidden() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 23, 9, 0)
        var persisted = makePersisted(now: now, calendar: calendar)
        persisted.showsDesktopPet = false
        let (runtime, _, _) = makeRuntime(now: now, calendar: calendar, persisted: persisted)

        #expect(runtime.situation.isHidden)
        #expect(runtime.perform(.greeting))
        #expect(runtime.renderedPose == .wave)
    }

    @Test func greetingSurvivesTicksDuringQuietHours() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 23, 23, 0)
        var persisted = makePersisted(now: now, calendar: calendar)
        persisted.quietWindow = QuietWindow(startMinutes: 22 * 60, endMinutes: 8 * 60)
        let (runtime, _, _) = makeRuntime(now: now, calendar: calendar, persisted: persisted)

        #expect(runtime.renderedPose == .sleep)
        #expect(runtime.perform(.greeting))
        #expect(runtime.renderedPose == .wave)

        runtime.send(.tick)
        #expect(runtime.renderedPose == .wave)
        #expect(runtime.currentTransientBehavior == .greeting)
    }
    @Test func carrySurvivesTicksWhileCompanionshipStaysIdle() {
        let calendar = testCalendar()
        let start = testDate(2026, 11, 23, 9, 0)
        var current = start
        let runtime = PetRuntime(
            renderer: TestPoseRenderer(),
            store: TestSessionStore(makePersisted(now: start, calendar: calendar)),
            now: { current },
            calendar: calendar
        )

        runtime.startSession()
        current = start.addingTimeInterval(45 * 60)
        runtime.send(.tick)
        runtime.send(.inviteAccepted)

        current = start.addingTimeInterval(45 * 60 + 30)
        runtime.send(.tick)
        #expect(runtime.situation.companion == .complete)

        current = start.addingTimeInterval(45 * 60 + 32.6)
        runtime.send(.tick)
        #expect(runtime.currentTransientBehavior == .carrying)
        #expect(runtime.renderedPose == .carry)

        // Next wake while companionship stays idle must not kill the leaf beat.
        current = start.addingTimeInterval(45 * 60 + 33)
        runtime.send(.tick)
        #expect(runtime.currentTransientBehavior == .carrying)
        #expect(runtime.renderedPose == .carry)
    }

    @Test func ambientGroomOnlyWhileAloneSitting() {
        let now = testDate(2026, 11, 23, 10, 0)
        var alone = PetSituation()
        #expect(alone.canPlayAmbientGroom(at: now))

        alone.isDozing = true
        #expect(!alone.canPlayAmbientGroom(at: now))

        alone.isDozing = false
        alone.session = CompanionSession(startedAt: now)
        alone.companion = .idle
        #expect(!alone.canPlayAmbientGroom(at: now))
        #expect(alone.resolvedPose(at: now) == .look)
    }

    @Test func playAmbientGroomHoldsTheGroomPose() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 23, 10, 0)
        let (runtime, _, _) = makeRuntime(now: now, calendar: calendar)

        #expect(runtime.playAmbientGroom())
        #expect(runtime.renderedPose == .groom)
        #expect(runtime.currentTransientBehavior == .grooming)

        runtime.startSession()
        #expect(runtime.currentTransientBehavior == nil)
        #expect(runtime.renderedPose == .look)
    }

    @Test func ambientGroomPlannerRespectsCooldown() {
        let start = testDate(2026, 11, 23, 10, 0)
        var planner = AmbientGroomPlanner()
        planner.reset(at: start) { _ in 30 }
        #expect(planner.isDue(at: start.addingTimeInterval(29)) == false)
        #expect(planner.isDue(at: start.addingTimeInterval(30)))

        planner.markFired(at: start.addingTimeInterval(30)) { _ in 60 }
        #expect(planner.isDue(at: start.addingTimeInterval(89)) == false)
        #expect(planner.isDue(at: start.addingTimeInterval(90)))
    }
}
