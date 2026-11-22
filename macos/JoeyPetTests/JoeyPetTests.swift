import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import JoeyPet

@MainActor
struct JoeyPetTests {
    @Test func restoredPositionFallsBackToMainScreen() {
        let screens = [PetScreenGeometry(
            identifier: "main",
            visibleFrame: PetPositionRect(minX: 0, minY: 0, width: 1440, height: 900),
            isMain: true
        )]
        let point = PetPositionGeometry.restore(nil, on: screens, windowSize: PetPositionPoint(x: 160, y: 160))
        #expect(point.x >= 0)
        #expect(point.y >= 0)
    }

    @Test func ambientDelayStaysWithinConfiguredBounds() {
        let configuration = AmbientBehaviorScheduler.Configuration(minimumDelay: 12, maximumDelay: 35)
        #expect(AmbientBehaviorScheduler.boundedDelay(1, configuration: configuration) == 12)
        #expect(AmbientBehaviorScheduler.boundedDelay(99, configuration: configuration) == 35)
    }

    @Test func appWindowBuildsWithV0Title() {
        let defaults = UserDefaults(suiteName: "JoeyPetTests")!
        defaults.removePersistentDomain(forName: "JoeyPetTests")
        let settings = AppSettings(defaults: defaults)

        let home = MainWindowController(
            settings: settings,
            onPrimaryAction: {}
        )
        #expect(home.window?.title == "Joey 的家")
        #expect(home.window?.contentView != nil)
        #expect(home.window?.minSize == NSSize(width: 880, height: 560))
    }

    @Test func settingsIsAnInWindowPage() {
        let navigation = NestNavigation()
        navigation.showReflection()
        navigation.openSettings()
        #expect(navigation.route == .settings)

        navigation.closeSettings()
        #expect(navigation.route == .reflection)

        navigation.toggleSettings()
        #expect(navigation.route == .settings)

        navigation.toggleSettings()
        #expect(navigation.route == .reflection)
    }

    @Test func desktopPetIsHiddenByDefault() {
        let defaults = UserDefaults(suiteName: "JoeyPetTestsDefaults")!
        defaults.removePersistentDomain(forName: "JoeyPetTestsDefaults")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.showsDesktopPet == false)
    }
}
