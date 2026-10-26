import AppKit
import Foundation

enum DebugStateInjector {
    static func injectedPetState() -> PetState? {
        #if DEBUG
        guard let value = debugArgumentValue(prefix: "-JoeyPetDebugState") else {
            return nil
        }
        return PetState(rawValue: value)
        #else
        return nil
        #endif
    }

    /// Debug-only pet package folder id under `Resources/Pets/`.
    /// Release builds always return `nil` (default `Joey`).
    static func injectedPackageID() -> String? {
        #if DEBUG
        return packageID(from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// Debug-only animation id for direct production-asset playback checks.
    static func injectedAnimationID() -> String? {
        #if DEBUG
        return animationID(from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// Debug-only transient / ambient behavior for Phase 3 playback checks.
    static func injectedTransientBehavior() -> PetTransientBehavior? {
        #if DEBUG
        return transientBehavior(from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// Parses `-JoeyPetDebugPet <id>` / `-JoeyPetDebugPet=<id>` from launch arguments.
    static func packageID(from arguments: [String]) -> String? {
        #if DEBUG
        return debugArgumentValue(prefix: "-JoeyPetDebugPet", arguments: arguments)
        #else
        return nil
        #endif
    }

    /// Parses `-JoeyPetDebugAnimation <id>` / `-JoeyPetDebugAnimation=<id>`.
    static func animationID(from arguments: [String]) -> String? {
        #if DEBUG
        return debugArgumentValue(prefix: "-JoeyPetDebugAnimation", arguments: arguments)
        #else
        return nil
        #endif
    }

    /// Debug GUI capture: `-JoeyPetQAOpenMain overview|cleanup|settings|maccare`
    static func qaMainWindowIntent() -> MainWindowIntent? {
        #if DEBUG
        guard let raw = debugArgumentValue(prefix: "-JoeyPetQAOpenMain") else { return nil }
        return AppShellState.intent(fromQAArgument: raw)
        #else
        return nil
        #endif
    }

    /// `-JoeyPetDebugMacCareHome normal|attention` — DEBUG-only home presentation fixture.
    static func macCareHomePresentationRaw() -> String? {
        #if DEBUG
        return debugArgumentValue(prefix: "-JoeyPetDebugMacCareHome")
        #else
        return nil
        #endif
    }

    /// DEBUG GUI capture: overlay live layout metrics for adaptive verification.
    static func qaShowsLayoutDebug() -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-JoeyPetQAShowLayoutDebug")
        #else
        false
        #endif
    }

    /// DEBUG GUI capture: `-JoeyPetQAWindowSize 1024x680` (points).
    static func qaWindowSize() -> CGSize? {
        #if DEBUG
        guard let raw = debugArgumentValue(prefix: "-JoeyPetQAWindowSize") else { return nil }
        let parts = raw.lowercased().split(separator: "x")
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1]),
              width > 0,
              height > 0
        else { return nil }
        return CGSize(width: width, height: height)
        #else
        return nil
        #endif
    }

    /// DEBUG GUI capture: `-JoeyPetQATheme dark|light` overrides the app appearance.
    static func qaAppearance() -> NSAppearance? {
        #if DEBUG
        guard let raw = debugArgumentValue(prefix: "-JoeyPetQATheme")?.lowercased() else { return nil }
        switch raw {
        case "dark": return NSAppearance(named: .darkAqua)
        case "light": return NSAppearance(named: .aqua)
        default: return nil
        }
        #else
        return nil
        #endif
    }

    /// DEBUG GUI capture: `-JoeyPetDebugHealth normal|attention|critical|unknown`.
    static func qaForcedHealthLevel() -> CalmSpaceHealthLevel? {
        #if DEBUG
        guard let raw = debugArgumentValue(prefix: "-JoeyPetDebugHealth") else { return nil }
        return CalmSpaceHealthLevel(rawValue: raw)
        #else
        return nil
        #endif
    }

    /// DEBUG QA driver: `-JoeyPetQAAutoSwitch <seconds>` alternates the Calm Space
    /// mode every N seconds (for screen recordings). Accepts 0.5...10 s.
    static func qaModeAutoSwitchInterval() -> TimeInterval? {
        #if DEBUG
        guard let raw = debugArgumentValue(prefix: "-JoeyPetQAAutoSwitch"),
              let seconds = TimeInterval(raw),
              (0.5...10).contains(seconds)
        else { return nil }
        return seconds
        #else
        return nil
        #endif
    }

    /// DEBUG QA driver: `-JoeyPetQARapidSwitch` fires a rapid burst of mode-switch
    /// requests through the same entry point the button uses; the guard must accept
    /// exactly one. Returns the fixed burst count.
    static func qaModeRapidSwitchBurst() -> Int? {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-JoeyPetQARapidSwitch") ? 6 : nil
        #else
        return nil
        #endif
    }

    /// DEBUG QA observability: `-JoeyPetQADebugRenderState` logs Calm Space transition
    /// and per-scene pause state changes via `OSLog`.
    static func qaLogsCalmSpaceRenderState() -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-JoeyPetQADebugRenderState")
        #else
        return false
        #endif
    }

    static func qaTriggersScan() -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-JoeyPetQATriggerScan")
        #else
        return false
        #endif
    }

    static func resetsPermissionOnboarding() -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-JoeyPetResetPermissionOnboarding")
        #else
        return false
        #endif
    }

    /// DEBUG-only isolation hook: hide the desktop pet panel to measure the main window in isolation.
    static func qaHidesPet() -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-JoeyPetQAHidePet")
        #else
        return false
        #endif
    }

    /// DEBUG-only isolation hook: suppress every main window (including onboarding) to measure the pet alone.
    static func qaSuppressesMainWindow() -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-JoeyPetQASuppressMainWindow")
        #else
        return false
        #endif
    }

    /// DEBUG-only isolation hook: render the main window as if Reduce Motion were enabled (no looping UI motion).
    static func qaForcesReduceMotion() -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-JoeyPetQAStaticUI")
        #else
        return false
        #endif
    }

    // MARK: - Calm Space Stage prototype (DEBUG-only, Unit 1)

    /// `-JoeyPetQAStagePrototype macCare|workRhythm` — enter the isolated Stage prototype.
    static func qaStagePrototypeMode() -> String? {
        #if DEBUG
        return debugArgumentValue(prefix: "-JoeyPetQAStagePrototype")
        #else
        return nil
        #endif
    }

    /// `-JoeyPetQAStageState normal|attention|critical|unknown|...[+activity]` — prototype
    /// state, optionally with an orthogonal activity overlay (`normal+scanning`).
    static func qaStageStateRaw() -> String? {
        #if DEBUG
        return debugArgumentValue(prefix: "-JoeyPetQAStageState")
        #else
        return nil
        #endif
    }

    /// `-JoeyPetQAStageFreeze` — freeze every prototype loop at a deterministic phase.
    static func qaStageFreezesAnimation() -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-JoeyPetQAStageFreeze")
        #else
        return false
        #endif
    }

    /// `-JoeyPetQAStageLongCopy` — use stress-test long copy fixtures.
    static func qaStageUsesLongCopy() -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-JoeyPetQAStageLongCopy")
        #else
        return false
        #endif
    }

    /// `-JoeyPetQAStageVariant a|b` — A/B exploration composition (default `a`).
    static func qaStageVariantRaw() -> String? {
        #if DEBUG
        return debugArgumentValue(prefix: "-JoeyPetQAStageVariant")
        #else
        return nil
        #endif
    }

    /// `-JoeyPetQASnapshotOut <abs path.png>` — render the prototype window offscreen to a
    /// PNG and exit. Used for QA capture on a locked display; the app renders its own
    /// window (no Screen Recording / TCC required). DEBUG-only.
    static func qaSnapshotOutputPath() -> String? {
        #if DEBUG
        return debugArgumentValue(prefix: "-JoeyPetQASnapshotOut")
        #else
        return nil
        #endif
    }

    /// Parses `-JoeyPetDebugBehavior <id>` / `-JoeyPetDebugBehavior=<id>`.
    static func transientBehavior(from arguments: [String]) -> PetTransientBehavior? {
        #if DEBUG
        guard let value = debugArgumentValue(prefix: "-JoeyPetDebugBehavior", arguments: arguments) else {
            return nil
        }
        return PetTransientBehavior(rawValue: value)
        #else
        return nil
        #endif
    }

    #if DEBUG
    private static func debugArgumentValue(
        prefix: String,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> String? {
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }

        let value: String
        if argument == prefix, let next = nextArgument(after: prefix, in: arguments) {
            value = next
        } else if argument.hasPrefix("\(prefix)=") {
            value = String(argument.dropFirst(prefix.count + 1))
        } else {
            value = String(argument.dropFirst(prefix.count))
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func nextArgument(after prefix: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: prefix), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }
    #endif
}
