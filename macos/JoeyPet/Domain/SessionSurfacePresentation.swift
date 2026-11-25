import Foundation

/// Pure mapping from the pet situation to the desktop surfaces that should be
/// on screen. The UI controller renders this value; the reducer stays the only
/// owner of product state.
struct SessionSurfacePresentation: Equatable, Sendable {
    let showsCompanionChip: Bool
    let showsInvitation: Bool
    let showsRecovery: Bool
    let recoveryEndsAt: Date?
    /// True on the first frame where a recovery turns into the completion beat.
    let newlyCompleted: Bool

    init(situation: PetSituation, previous: PetSituation?, now: Date) {
        let desktop = situation.resolvedDesktop(at: now)
        // Hidden invite reveals the panel with desktop `.companion`; keep the
        // chip so the temporary reveal still reads as an active session.
        showsCompanionChip = situation.session != nil && desktop == .companion
        showsInvitation = situation.isInviteCardVisible(at: now)
        showsRecovery = situation.isRecoveryPanelVisible(at: now)
            && situation.recoveryEndsAt != nil
        recoveryEndsAt = situation.recoveryEndsAt
        newlyCompleted = situation.companion == .complete && previous?.companion != .complete
    }
}

/// Session clock text used by the desktop chip and the nest chip.
enum CompanionTimeText {
    /// `mm:ss`, with minutes growing past 99 instead of wrapping.
    static func elapsedText(from start: Date, to now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
