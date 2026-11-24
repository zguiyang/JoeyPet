import Foundation

// MARK: - Runtime vocabulary

enum PetBehaviorBucket: String, CaseIterable, Codable, Sendable {
    case idle
    case notifying
    case sleeping
    case celebrating
}

enum PetPose: String, CaseIterable, Codable, Sendable {
    case sit
    case look
    case sign
    case stretch
    case happy
    case wave
    case sleep
    case groom
    case yawn
    case doze
    case peek
    case carry
}

enum PetAmbientEvent: String, CaseIterable, Codable, Sendable {
    case breathe
    case blink
    case ear
    case tail
    case shift
    case groom
    case yawn
    case peek
}

enum DesktopState: String, CaseIterable, Codable, Sendable {
    case dragging
    case hidden
    case quiet
    case doNotDisturb
    case snoozed
    case companion
    case alone

    var priority: Int {
        switch self {
        case .dragging: 1
        case .hidden: 2
        case .quiet: 3
        case .doNotDisturb: 4
        case .snoozed: 5
        case .companion: 6
        case .alone: 7
        }
    }

    var defaultPose: PetPose? {
        switch self {
        case .dragging: .look
        case .hidden: nil
        case .quiet: .sleep
        case .doNotDisturb: .doze
        case .snoozed: .sit
        case .companion: .look
        case .alone: .sit
        }
    }
}

enum CompanionSubstate: String, CaseIterable, Codable, Sendable {
    case idle
    case approach
    case invite
    case recover
    case complete
}

// MARK: - Policies

struct QuietWindow: Equatable, Sendable {
    var startMinutes: Int
    var endMinutes: Int

    init(startMinutes: Int = 22 * 60, endMinutes: Int = 8 * 60) {
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
    }

    /// Equal start/end means "no quiet window" rather than a 24-hour window.
    func isActive(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard startMinutes != endMinutes else { return false }
        let minutes = Self.minutesSinceMidnight(for: date, calendar: calendar)
        if startMinutes < endMinutes {
            return minutes >= startMinutes && minutes < endMinutes
        }
        return minutes >= startMinutes || minutes < endMinutes
    }

    static func minutesSinceMidnight(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// The next instant at which `isActive(at:)` may change.
    func nextBoundary(after date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        guard startMinutes != endMinutes else { return nil }

        let startOfDay = calendar.startOfDay(for: date)
        var candidates: [Date] = []
        for dayOffset in 0...1 {
            guard let base = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay)
            else { continue }
            if let start = calendar.date(byAdding: .minute, value: startMinutes, to: base) {
                candidates.append(start)
            }
            if let end = calendar.date(byAdding: .minute, value: endMinutes, to: base) {
                candidates.append(end)
            }
        }
        return candidates.filter { $0 > date }.min()
    }

    static func minutes(from clock: String) -> Int? {
        let parts = clock.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute)
        else {
            return nil
        }
        return hour * 60 + minute
    }
}

struct InvitationPolicy: Equatable, Sendable {
    var minimumGapMinutes: Int
    var rhythmMinutes: Int
    var snoozeMinutes: Int
    var approachLeadMinutes: Int
    var recoveryDuration: TimeInterval
    var completeDuration: TimeInterval
    /// How long a hidden Joey may surface for one invitation before returning to hiding.
    var hiddenRevealDuration: TimeInterval

    init(
        minimumGapMinutes: Int = 45,
        rhythmMinutes: Int = 45,
        snoozeMinutes: Int = 10,
        approachLeadMinutes: Int = 5,
        recoveryDuration: TimeInterval = 30,
        completeDuration: TimeInterval = 2.6,
        hiddenRevealDuration: TimeInterval = 60
    ) {
        self.minimumGapMinutes = minimumGapMinutes
        self.rhythmMinutes = rhythmMinutes
        self.snoozeMinutes = snoozeMinutes
        self.approachLeadMinutes = approachLeadMinutes
        self.recoveryDuration = recoveryDuration
        self.completeDuration = completeDuration
        self.hiddenRevealDuration = hiddenRevealDuration
    }

    /// The atlas allows 45 / 60 / 90 minutes, with 45 as a hard floor.
    var effectiveGapMinutes: Int {
        max(minimumGapMinutes, max(45, rhythmMinutes))
    }

    var effectiveGap: TimeInterval {
        TimeInterval(effectiveGapMinutes) * 60
    }

    func firstDue(sessionStart: Date) -> Date {
        sessionStart.addingTimeInterval(effectiveGap)
    }

    func nextDue(sessionStart: Date, lastClosed: Date?) -> Date {
        let base = max(sessionStart, lastClosed ?? .distantPast)
        return base.addingTimeInterval(effectiveGap)
    }

    func approachStart(due: Date) -> Date {
        due.addingTimeInterval(-TimeInterval(approachLeadMinutes) * 60)
    }
}

struct PresencePolicy: Equatable, Sendable {
    var idleThreshold: TimeInterval
    var awayThreshold: TimeInterval
    var wakeGuard: TimeInterval
    var yawnDuration: TimeInterval

    init(
        idleThreshold: TimeInterval = 90,
        awayThreshold: TimeInterval = 30 * 60,
        wakeGuard: TimeInterval = 2,
        yawnDuration: TimeInterval = 1.8
    ) {
        self.idleThreshold = idleThreshold
        self.awayThreshold = awayThreshold
        self.wakeGuard = wakeGuard
        self.yawnDuration = yawnDuration
    }
}

struct CompanionSession: Equatable, Sendable {
    let startedAt: Date

    func elapsed(at now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(startedAt))
    }
}

// MARK: - Situation

/// The single source of truth for the pet's product state.
///
/// `desktop` and `pose` are derived from flags and deadlines so a higher-priority
/// state can override the pose without destroying lower-priority timers.
struct PetSituation: Equatable, Sendable {
    var isDragging = false
    var isHidden = false
    var isDoNotDisturb = false
    var isQuietActive = false
    /// When a hidden Joey surfaces for an invitation, this starts the auto-hide clock.
    var inviteShownAt: Date?
    var snoozeUntil: Date?
    var dragSettledAt: Date?

    var session: CompanionSession?
    var companion: CompanionSubstate?
    var lastInvitationClosedAt: Date?
    var snoozeUsedThisSession = false
    var recoveryEndsAt: Date?
    var completeEndsAt: Date?

    var isDozing = false
    var isYawning = false
    var yawnUntil: Date?
    var wasAwayLong = false

    var isMenuOpen = false
    var isSystemSleeping = false
    var isScreenLocked = false
    var isReduceMotion = false
    var isLowPowerMode = false
    var isAmbientEnabled = true

    var quietWindow = QuietWindow()
    var policy = InvitationPolicy()
    var presence = PresencePolicy()

    static func restored(
        from persisted: PetPersistedState,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> PetSituation {
        var situation = PetSituation()
        situation.isDoNotDisturb = persisted.isDoNotDisturb
        situation.lastInvitationClosedAt = persisted.lastInvitationClosedAt
        situation.quietWindow = persisted.quietWindow
        situation.policy.rhythmMinutes = persisted.rhythmMinutes
        situation.isQuietActive = persisted.quietWindow.isActive(at: now, calendar: calendar)
        situation.isHidden = !persisted.showsDesktopPet
        return situation
    }

    func isSnoozeActive(at now: Date) -> Bool {
        guard let snoozeUntil else { return false }
        return snoozeUntil > now
    }

    /// Do-not-disturb, quiet hours and system states all silence invitations.
    var promptsSuppressed: Bool {
        isDoNotDisturb || isQuietActive || isSystemSleeping || isScreenLocked
    }

    /// A hidden Joey only returns to the desktop to deliver an active prompt.
    func isTemporarilyRevealed(at now: Date) -> Bool {
        guard isHidden, !promptsSuppressed else { return false }
        switch companion {
        case .invite, .recover, .complete:
            return true
        default:
            return false
        }
    }

    /// States whose pose must win over an in-flight ambient transient
    /// immediately instead of waiting for it to finish.
    var interruptsAmbientTransient: Bool {
        isDragging || isHidden || isQuietActive || isMenuOpen
            || isSystemSleeping || isScreenLocked
            || isDozing || isYawning || session != nil
    }

    /// Whether the desktop panel should be on screen. Hidden mode is silent
    /// except while an invitation, recovery or completion is on display.
    func shouldShowPanel(at now: Date) -> Bool {
        !isHidden || isTemporarilyRevealed(at: now)
    }

    func resolvedDesktop(at now: Date) -> DesktopState {
        if isDragging { return .dragging }
        if isHidden, !isTemporarilyRevealed(at: now) { return .hidden }
        if isQuietActive { return .quiet }
        if isDoNotDisturb { return .doNotDisturb }
        if isSnoozeActive(at: now) { return .snoozed }
        if session != nil { return .companion }
        return .alone
    }

    func resolvedPose(at now: Date) -> PetPose {
        switch resolvedDesktop(at: now) {
        case .hidden:
            return .sit
        case .dragging:
            return .look
        case .quiet:
            if companion == .recover { return .stretch }
            if companion == .complete { return .happy }
            return .sleep
        case .doNotDisturb:
            return .doze
        case .snoozed:
            if companion == .recover { return .stretch }
            if companion == .complete { return .happy }
            if isYawnActive(at: now) { return .yawn }
            if isDozing { return .doze }
            return .sit
        case .companion:
            switch companion {
            case .recover: return .stretch
            case .complete: return .happy
            case .invite: return .look
            case .approach, .idle, nil: return .look
            }
        case .alone:
            if isYawnActive(at: now) { return .yawn }
            if isDozing { return .doze }
            return .sit
        }
    }

    func isYawnActive(at now: Date) -> Bool {
        guard isYawning, let yawnUntil else { return false }
        return yawnUntil > now
    }

    func isInviteCardVisible(at now: Date) -> Bool {
        guard session != nil, companion == .invite, !promptsSuppressed else {
            return false
        }
        if isSnoozeActive(at: now) { return false }
        return true
    }

    /// Quiet hours may finish a running recovery, so only DND and system
    /// states hide the panel.
    func isRecoveryPanelVisible(at now: Date) -> Bool {
        guard session != nil, companion == .recover else { return false }
        return !isDoNotDisturb && !isSystemSleeping && !isScreenLocked
    }

    func invitationDueDate() -> Date? {
        guard let session else { return nil }
        return policy.nextDue(sessionStart: session.startedAt, lastClosed: lastInvitationClosedAt)
    }

    func approachStartDate() -> Date? {
        guard let due = invitationDueDate() else { return nil }
        return policy.approachStart(due: due)
    }

    /// The moment a hidden invitation reveals itself.
    func hiddenRevealDeadline() -> Date? {
        guard isHidden, companion == .invite, let inviteShownAt else { return nil }
        return inviteShownAt.addingTimeInterval(policy.hiddenRevealDuration)
    }

    func canEnterDoze(at now: Date) -> Bool {
        let desktop = resolvedDesktop(at: now)
        guard desktop == .alone || desktop == .snoozed else {
            return false
        }
        guard !isMenuOpen, !isDragging, !isHidden else { return false }
        guard !isInviteCardVisible(at: now), !isRecoveryPanelVisible(at: now) else { return false }
        guard !isSystemSleeping, !isScreenLocked else { return false }
        return true
    }
}

// MARK: - Persistence

struct PetPersistedState: Equatable, Sendable {
    var isDoNotDisturb: Bool
    var lastInvitationClosedAt: Date?
    var todayKey: String
    var todayCompanionshipSeconds: Int
    var todayBreaks: Int
    var weekStartKey: String
    var weekBreakCounts: [Int]
    var quietWindow: QuietWindow
    var rhythmMinutes: Int
    var showsDesktopPet: Bool

    static func empty(
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> PetPersistedState {
        PetPersistedState(
            isDoNotDisturb: false,
            lastInvitationClosedAt: nil,
            todayKey: PetDayKey.dayKey(for: now, calendar: calendar),
            todayCompanionshipSeconds: 0,
            todayBreaks: 0,
            weekStartKey: PetDayKey.weekStartKey(for: now, calendar: calendar),
            weekBreakCounts: Array(repeating: 0, count: 7),
            quietWindow: QuietWindow(),
            rhythmMinutes: 45,
            showsDesktopPet: false
        )
    }

    func normalized(now: Date, calendar: Calendar = .autoupdatingCurrent) -> PetPersistedState {
        var copy = self

        if copy.todayKey != PetDayKey.dayKey(for: now, calendar: calendar) {
            copy.todayKey = PetDayKey.dayKey(for: now, calendar: calendar)
            copy.todayCompanionshipSeconds = 0
            copy.todayBreaks = 0
        }
        if copy.weekStartKey != PetDayKey.weekStartKey(for: now, calendar: calendar) {
            copy.weekStartKey = PetDayKey.weekStartKey(for: now, calendar: calendar)
            copy.weekBreakCounts = Array(repeating: 0, count: 7)
        }
        if copy.weekBreakCounts.count != 7 {
            copy.weekBreakCounts = Array(repeating: 0, count: 7)
        }
        copy.weekBreakCounts = copy.weekBreakCounts.map { max(0, $0) }
        copy.todayCompanionshipSeconds = max(0, copy.todayCompanionshipSeconds)
        copy.todayBreaks = max(0, copy.todayBreaks)

        if ![45, 60, 90].contains(copy.rhythmMinutes) {
            copy.rhythmMinutes = 45
        }
        if !(0...1439).contains(copy.quietWindow.startMinutes) {
            copy.quietWindow.startMinutes = 22 * 60
        }
        if !(0...1439).contains(copy.quietWindow.endMinutes) {
            copy.quietWindow.endMinutes = 8 * 60
        }
        return copy
    }
}

enum PetDayKey {
    static func dayKey(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func weekStartKey(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let start = mondayCalendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return dayKey(for: start, calendar: mondayCalendar)
    }

    /// Monday = 0 … Sunday = 6.
    static func weekdayIndex(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let weekday = mondayCalendar.component(.weekday, from: date)
        return (weekday + 5) % 7
    }
}

@MainActor
protocol PetSessionStoring: AnyObject {
    func load(now: Date, calendar: Calendar) -> PetPersistedState
    func save(_ state: PetPersistedState)
}

@MainActor
final class UserDefaultsPetSessionStore: PetSessionStoring {
    private enum Key {
        static let rhythm = "joey.rhythmMinutes"
        static let doNotDisturb = "joey.doNotDisturb"
        static let quietStart = "joey.quietStartMinutes"
        static let quietEnd = "joey.quietEndMinutes"
        static let lastInvitationClosedAt = "joey.lastInvitationClosedAt"
        static let todayKey = "joey.todayKey"
        static let todayCompanionshipSeconds = "joey.todayCompanionshipSeconds"
        static let todayBreaks = "joey.todayBreaks"
        static let weekStartKey = "joey.weekStartKey"
        static let weekBreakCounts = "joey.weekBreakCounts"
        static let showsDesktopPet = PetPreferences.showsDesktopPetKey
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(now: Date, calendar: Calendar = .autoupdatingCurrent) -> PetPersistedState {
        let quietStart = defaults.object(forKey: Key.quietStart) as? Int ?? 22 * 60
        let quietEnd = defaults.object(forKey: Key.quietEnd) as? Int ?? 8 * 60
        let rhythm = defaults.object(forKey: Key.rhythm) as? Int ?? 45

        let state = PetPersistedState(
            isDoNotDisturb: defaults.object(forKey: Key.doNotDisturb) as? Bool ?? false,
            lastInvitationClosedAt: date(forKey: Key.lastInvitationClosedAt),
            todayKey: defaults.string(forKey: Key.todayKey) ?? "",
            todayCompanionshipSeconds: defaults.integer(forKey: Key.todayCompanionshipSeconds),
            todayBreaks: defaults.integer(forKey: Key.todayBreaks),
            weekStartKey: defaults.string(forKey: Key.weekStartKey) ?? "",
            weekBreakCounts: defaults.array(forKey: Key.weekBreakCounts) as? [Int]
                ?? Array(repeating: 0, count: 7),
            quietWindow: QuietWindow(startMinutes: quietStart, endMinutes: quietEnd),
            rhythmMinutes: rhythm,
            showsDesktopPet: PetPreferences.showsDesktopPet(defaults: defaults)
        )
        return state.normalized(now: now, calendar: calendar)
    }

    func save(_ state: PetPersistedState) {
        defaults.set(state.isDoNotDisturb, forKey: Key.doNotDisturb)
        setDate(state.lastInvitationClosedAt, forKey: Key.lastInvitationClosedAt)
        defaults.set(state.todayKey, forKey: Key.todayKey)
        defaults.set(state.todayCompanionshipSeconds, forKey: Key.todayCompanionshipSeconds)
        defaults.set(state.todayBreaks, forKey: Key.todayBreaks)
        defaults.set(state.weekStartKey, forKey: Key.weekStartKey)
        defaults.set(state.weekBreakCounts, forKey: Key.weekBreakCounts)
        defaults.set(state.quietWindow.startMinutes, forKey: Key.quietStart)
        defaults.set(state.quietWindow.endMinutes, forKey: Key.quietEnd)
        defaults.set(state.rhythmMinutes, forKey: Key.rhythm)
        defaults.set(state.showsDesktopPet, forKey: Key.showsDesktopPet)
    }

    private func date(forKey key: String) -> Date? {
        guard let timestamp = defaults.object(forKey: key) as? Double else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func setDate(_ date: Date?, forKey key: String) {
        if let date {
            defaults.set(date.timeIntervalSince1970, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
