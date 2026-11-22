import Foundation

enum PetPreferences {
    static let ambientBehaviorsEnabledKey = "ambientBehaviorsEnabled"
    static let showsDesktopPetKey = "showsDesktopPet"

    static let defaultAmbientBehaviorsEnabled = true
    /// The pet is hidden by default while the companion line is rebuilt.
    static let defaultShowsDesktopPet = false

    static func ambientBehaviorsEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: ambientBehaviorsEnabledKey) as? Bool ?? defaultAmbientBehaviorsEnabled
    }

    static func showsDesktopPet(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: showsDesktopPetKey) as? Bool ?? defaultShowsDesktopPet
    }

    static func setShowsDesktopPet(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: showsDesktopPetKey)
    }

}
