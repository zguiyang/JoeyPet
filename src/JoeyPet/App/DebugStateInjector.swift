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

    static func qaTriggersScan() -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-JoeyPetQATriggerScan")
        #else
        return false
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
