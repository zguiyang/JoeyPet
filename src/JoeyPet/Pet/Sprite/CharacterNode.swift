import SpriteKit

@MainActor
final class CharacterNode: SKSpriteNode {
    private var currentAnimationID: String?

    init(texture: SKTexture?, displayScaleFactor: CGFloat, textureFiltering: SKTextureFilteringMode = .nearest) {
        super.init(texture: texture, color: .clear, size: texture?.size() ?? .zero)
        setScale(displayScaleFactor)
        texture?.filteringMode = textureFiltering
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func playAnimation(
        id: String,
        clip: AnimationClip,
        textures: [SKTexture],
        completion: (() -> Void)? = nil
    ) {
        guard currentAnimationID != id else { return }
        currentAnimationID = id

        let frameTextures = clip.frames.map { textures[$0] }
        guard !frameTextures.isEmpty else { return }

        removeAction(forKey: "petAnimation")
        let frameDuration = 1.0 / clip.fps
        let animate = SKAction.animate(with: frameTextures, timePerFrame: frameDuration)

        if clip.loop {
            run(.repeatForever(animate), withKey: "petAnimation")
        } else {
            let actions: [SKAction] = completion.map { [animate, .run($0)] } ?? [animate]
            run(.sequence(actions), withKey: "petAnimation")
        }
    }

    func applyStatusSeverity(_ severity: SignalSeverity) {
        color = severity.statusColor
        colorBlendFactor = severity == .normal ? 0 : 0.22
    }
}
