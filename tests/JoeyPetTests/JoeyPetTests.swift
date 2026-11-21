import CoreGraphics
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
}
