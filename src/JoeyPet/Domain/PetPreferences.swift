import Foundation

enum PetPreferences {
    static let ambientBehaviorsEnabledKey = "ambientBehaviorsEnabled"
    static let proactiveBubblesEnabledKey = "proactiveBubblesEnabled"
    static let lastCleanupSummaryKey = "lastCleanupSummary"

    static let defaultAmbientBehaviorsEnabled = true
    static let defaultProactiveBubblesEnabled = true

    static func ambientBehaviorsEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: ambientBehaviorsEnabledKey) as? Bool ?? defaultAmbientBehaviorsEnabled
    }

    static func proactiveBubblesEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: proactiveBubblesEnabledKey) as? Bool ?? defaultProactiveBubblesEnabled
    }

    static func allowsProactiveBubble(isUserInitiated: Bool, defaults: UserDefaults = .standard) -> Bool {
        isUserInitiated || proactiveBubblesEnabled(defaults: defaults)
    }
}
