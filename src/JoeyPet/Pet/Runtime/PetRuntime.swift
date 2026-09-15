import Foundation
import OSLog
import SpriteKit

@MainActor
final class PetRuntime {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PetRuntime")

    private(set) var currentState: PetState = .idle
    let scene: PetScene

    init(sceneSize: CGSize) {
        self.scene = PetScene(size: sceneSize)
        scene.applyState(.idle)
    }

    func apply(behavior: PetBehavior) {
        guard behavior.state != currentState else { return }
        currentState = behavior.state
        scene.applyState(behavior.state)
        Self.logger.info("PetRuntime state -> \(behavior.state.rawValue, privacy: .public)")
    }
}
