import SpriteKit

@MainActor
final class PetRootNode: SKNode {
    let character: CharacterNode
    let effects = SKNode()

    init(character: CharacterNode) {
        self.character = character
        super.init()
        addChild(character)
        addChild(effects)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }
}
