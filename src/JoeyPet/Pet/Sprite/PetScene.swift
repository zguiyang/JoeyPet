import SpriteKit

@MainActor
final class PetScene: SKScene {
    static let interactiveRadius: CGFloat = 44

    private let rootNode: PetRootNode
    private let package: LoadedPetPackage
    private var displayedAnimationID: String?

    init(size: CGSize, package: LoadedPetPackage) {
        self.package = package

        let initialTexture = package.frameTextures.first
        let character = CharacterNode(
            texture: initialTexture,
            displayScale: package.manifest.defaultScale
        )
        rootNode = PetRootNode(character: character)

        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        setupNodes()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func applyAnimation(_ animationID: String, completion: (() -> Void)? = nil) {
        let resolvedID = PetManifestValidator.resolvedAnimationID(
            requestedID: animationID,
            manifest: package.manifest
        )
        guard displayedAnimationID != resolvedID else { return }
        displayedAnimationID = resolvedID

        guard let clip = package.clipsByID[resolvedID] else { return }
        rootNode.character.playAnimation(
            id: resolvedID,
            clip: clip,
            textures: package.frameTextures,
            completion: completion
        )
    }

    private func setupNodes() {
        rootNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(rootNode)
    }
}
