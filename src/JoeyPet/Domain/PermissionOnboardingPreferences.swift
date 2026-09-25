import Foundation

enum PermissionOnboardingPreferences {
    static let hasCompletedKey = "hasCompletedPermissionOnboarding"

    static func hasCompleted(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: hasCompletedKey)
    }

    static func markCompleted(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: hasCompletedKey)
    }

    #if DEBUG
    static func resetForDevelopment(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: hasCompletedKey)
    }
    #endif
}

enum PermissionOnboardingGate {
    /// Onboarding UI should show when the user has not decided yet and FDA is not verified.
    static func shouldPresentOnboarding(hasCompleted: Bool, fullDiskAccessStatus: FullDiskAccessStatus) -> Bool {
        !hasCompleted && fullDiskAccessStatus != .granted
    }

    /// First launch with FDA already granted skips the onboarding screen but still marks completion.
    static func shouldAutoCompleteOnLaunch(hasCompleted: Bool, fullDiskAccessStatus: FullDiskAccessStatus) -> Bool {
        !hasCompleted && fullDiskAccessStatus == .granted
    }
}
