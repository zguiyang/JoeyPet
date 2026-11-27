import Foundation

/// One short recovery prescription shown on the invite card and recovery panel.
/// Not medical advice — durations echo common microbreak guidance (20-20-20,
/// Stanford-style microbreaks, active walk breaks, hydration nudges).
struct RecoveryRecipe: Equatable, Sendable, Identifiable {
    var id: RecoveryRecipeID
    /// Seconds on the recovery ring. Clamped to ``durationMinimum``…``durationMaximum``.
    var durationSec: TimeInterval
    /// Invite card body (may include a newline).
    var inviteCopy: String
    var recoveryTitle: String
    var recoveryHint: String
    /// VoiceOver status while recovering.
    var accessibilityRecovering: String

    static let durationMinimum: TimeInterval = 20
    static let durationMaximum: TimeInterval = 180

    var clampedDurationSec: TimeInterval {
        min(max(durationSec, Self.durationMinimum), Self.durationMaximum)
    }
}

enum RecoveryRecipeID: String, Equatable, Sendable, CaseIterable {
    case lookFar
    case standBlink
    case walkStretch
    case hydrate
}

/// Fixed catalog + deterministic picker for one companionship session.
enum RecoveryRecipeCatalog {
    /// Rotation order for `sessionAcceptedIndex % count` (before window force).
    static let rotation: [RecoveryRecipeID] = [
        .lookFar,
        .standBlink,
        .walkStretch,
        .hydrate
    ]

    static let all: [RecoveryRecipe] = [
        RecoveryRecipe(
            id: .lookFar,
            durationSec: 30,
            inviteCopy: "坐久啦，\n看远处歇一下？",
            recoveryTitle: "望向远处",
            recoveryHint: "找个远处的点，眼睛放松",
            accessibilityRecovering: "正在望向远处"
        ),
        RecoveryRecipe(
            id: .standBlink,
            durationSec: 45,
            inviteCopy: "起来站一会儿，\n揉揉眼？",
            recoveryTitle: "站立揉眼",
            recoveryHint: "站直，轻轻揉揉眼周",
            accessibilityRecovering: "正在站立揉眼"
        ),
        RecoveryRecipe(
            id: .walkStretch,
            durationSec: 120,
            inviteCopy: "起来走两步，\n伸个懒腰？",
            recoveryTitle: "走动伸展",
            recoveryHint: "离开座位走一走，伸展一下",
            accessibilityRecovering: "正在走动伸展"
        ),
        RecoveryRecipe(
            id: .hydrate,
            durationSec: 25,
            inviteCopy: "喝口水\n再继续？",
            recoveryTitle: "喝一口水",
            recoveryHint: "喝一小口，再坐下",
            accessibilityRecovering: "正在喝水休息"
        )
    ]

    static func recipe(id: RecoveryRecipeID) -> RecoveryRecipe {
        all.first { $0.id == id } ?? all[0]
    }

    /// Picks the next recipe for this session.
    ///
    /// - Parameters:
    ///   - sessionAcceptedIndex: how many recoveries were already accepted this session (0-based next slot).
    ///   - lastRecipeID: previous invite/recover id, if any, to avoid an immediate repeat.
    static func pick(
        sessionAcceptedIndex: Int,
        lastRecipeID: RecoveryRecipeID? = nil
    ) -> RecoveryRecipe {
        let index = max(0, sessionAcceptedIndex)
        var id: RecoveryRecipeID

        if index == 0 {
            id = .lookFar
        } else if index % 3 == 2 {
            // Every third accept is a longer walk/stretch (active microbreak slot).
            id = .walkStretch
        } else {
            id = rotation[index % rotation.count]
        }

        if let last = lastRecipeID, id == last {
            id = nextID(after: id)
        }

        return recipe(id: id)
    }

    private static func nextID(after id: RecoveryRecipeID) -> RecoveryRecipeID {
        guard let idx = rotation.firstIndex(of: id) else { return .lookFar }
        return rotation[(idx + 1) % rotation.count]
    }
}
