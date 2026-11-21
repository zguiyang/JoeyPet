import Foundation

/// Narrow Debug-only hooks for checking real pet assets without product fixtures.
enum DebugStateInjector {
    static func injectedPackageID() -> String? {
        #if DEBUG
        value(for: "-JoeyPetDebugPet")
        #else
        nil
        #endif
    }

    static func injectedAnimationID() -> String? {
        #if DEBUG
        value(for: "-JoeyPetDebugAnimation")
        #else
        nil
        #endif
    }

    static func injectedTransientBehavior() -> PetTransientBehavior? {
        #if DEBUG
        value(for: "-JoeyPetDebugBehavior").flatMap(PetTransientBehavior.init(rawValue:))
        #else
        nil
        #endif
    }

    #if DEBUG
    private static func value(for prefix: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: prefix), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
    #endif
}
