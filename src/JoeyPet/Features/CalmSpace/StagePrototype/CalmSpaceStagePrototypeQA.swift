import Foundation

#if DEBUG
/// Which Stage prototype to show.
enum CalmSpaceStagePrototypeMode: String {
    case macCare
    case workRhythm
}

/// A prototype state. The first four are real Mac Care health levels; the rest are
/// Work Rhythm placeholders that Unit 2 will fill in (recognised but not designed yet).
enum CalmSpaceStageVariant: String {
    case a   // refined digital planet (orbit band + asymmetric-lit disc)
    case b   // horizon / atmosphere-band energy body (lit limb, no orbit)
}

/// A prototype state. The first four are real Mac Care health levels; the rest are
/// Work Rhythm placeholders that Unit 2 will fill in (recognised but not designed yet).
enum CalmSpaceStagePrototypeState: String {
    case normal, attention, critical, unknown
    case idle, focus, paused, rest, complete

    /// The Mac Care health level this state maps to. Work Rhythm states have no health
    /// meaning and fall back to `normal` for the (unused) body material.
    var healthLevel: CalmSpaceHealthLevel {
        switch self {
        case .normal: return .normal
        case .attention: return .attention
        case .critical: return .critical
        case .unknown: return .unknown
        default: return .normal
        }
    }

    var isMacCare: Bool {
        switch self {
        case .normal, .attention, .critical, .unknown: return true
        default: return false
        }
    }
}

/// Parsed DEBUG-only launch configuration for the isolated Stage prototype.
///
/// Presence of `-JoeyPetQAStagePrototype` swaps the whole Calm Space root for the
/// prototype page. Nothing here compiles into Release and nothing here reads real
/// timing / scanning business data — all content comes from `StagePrototypeFixtures`.
struct CalmSpaceStagePrototypeQA {
    let mode: CalmSpaceStagePrototypeMode
    let state: CalmSpaceStagePrototypeState
    /// Orthogonal activity overlay (`-JoeyPetQAStageState normal+scanning`). Kept separate
    /// from the state enum so the reserved activity slot can be exercised on any state.
    let activity: MacCareStageActivity?
    /// A/B exploration composition.
    let variant: CalmSpaceStageVariant
    /// `-JoeyPetQAStageFreeze`: park every loop at a deterministic phase for reproducible
    /// screenshots. Does not change the static design.
    let freeze: Bool
    /// `-JoeyPetQAStageLongCopy`: use stress-test long copy fixtures.
    let longCopy: Bool

    static var config: CalmSpaceStagePrototypeQA? {
        guard let rawMode = DebugStateInjector.qaStagePrototypeMode() else { return nil }
        let mode = CalmSpaceStagePrototypeMode(rawValue: rawMode) ?? .macCare

        // `-JoeyPetQAStageState base[+activity]` — the activity suffix is optional.
        let rawState = DebugStateInjector.qaStageStateRaw() ?? ""
        let parts = rawState.split(separator: "+", maxSplits: 1).map(String.init)
        let base = parts.first ?? ""
        let activityTag = parts.count > 1 ? parts[1] : nil
        let state = CalmSpaceStagePrototypeState(rawValue: base) ?? .normal

        let rawVariant = DebugStateInjector.qaStageVariantRaw() ?? ""
        let variant = CalmSpaceStageVariant(rawValue: rawVariant) ?? .a

        return CalmSpaceStagePrototypeQA(
            mode: mode,
            state: state,
            activity: Self.activity(for: activityTag),
            variant: variant,
            freeze: DebugStateInjector.qaStageFreezesAnimation(),
            longCopy: DebugStateInjector.qaStageUsesLongCopy()
        )
    }

    private static func activity(for tag: String?) -> MacCareStageActivity? {
        switch tag {
        case "scanning": return StagePrototypeFixtures.scanningActivity
        case "complete": return StagePrototypeFixtures.completeActivity
        case "maintenance": return StagePrototypeFixtures.maintenanceActivity
        default: return nil
        }
    }

    /// True when every looping animation must be parked (freeze or Reduce Motion).
    func isFrozen(reduceMotion: Bool) -> Bool {
        freeze || reduceMotion
    }
}
#endif
