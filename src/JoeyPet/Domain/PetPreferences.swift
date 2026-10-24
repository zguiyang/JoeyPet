import Foundation

enum PetPreferences {
    static let ambientBehaviorsEnabledKey = "ambientBehaviorsEnabled"
    static let proactiveBubblesEnabledKey = "proactiveBubblesEnabled"
    static let showsDesktopPetKey = "showsDesktopPet"
    static let lastCleanupSummaryKey = "lastCleanupSummary"

    static let defaultAmbientBehaviorsEnabled = true
    static let defaultProactiveBubblesEnabled = true
    /// Hidden by default while the main-window experience is being finished.
    static let defaultShowsDesktopPet = false

    static func ambientBehaviorsEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: ambientBehaviorsEnabledKey) as? Bool ?? defaultAmbientBehaviorsEnabled
    }

    static func proactiveBubblesEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: proactiveBubblesEnabledKey) as? Bool ?? defaultProactiveBubblesEnabled
    }

    static func showsDesktopPet(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: showsDesktopPetKey) as? Bool ?? defaultShowsDesktopPet
    }

    static func setShowsDesktopPet(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: showsDesktopPetKey)
    }

    static func allowsProactiveBubble(isUserInitiated: Bool, defaults: UserDefaults = .standard) -> Bool {
        isUserInitiated || proactiveBubblesEnabled(defaults: defaults)
    }
}
