import SpriteKit

@MainActor
final class PetScene: SKScene {
    static let interactiveRadius: CGFloat = 44

    private var bodyNode = SKShapeNode(circleOfRadius: 34)
    private var faceNode = SKLabelNode(text: "Joey")
    private var effectNode = SKNode()
    private var displayedState: PetState?

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        setupNodes()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func applyState(_ state: PetState) {
        guard displayedState != state else { return }
        displayedState = state
        render(state)
    }

    private func setupNodes() {
        bodyNode.fillColor = NSColor.systemOrange.withAlphaComponent(0.92)
        bodyNode.strokeColor = NSColor.systemBrown
        bodyNode.lineWidth = 2
        bodyNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(bodyNode)

        faceNode.fontName = "Helvetica-Bold"
        faceNode.fontSize = 14
        faceNode.fontColor = .white
        faceNode.verticalAlignmentMode = .center
        faceNode.position = bodyNode.position
        addChild(faceNode)

        effectNode.position = bodyNode.position
        addChild(effectNode)
    }

    private func render(_ state: PetState) {
        bodyNode.removeAllActions()
        faceNode.removeAllActions()
        effectNode.removeAllActions()
        effectNode.removeAllChildren()

        switch state {
        case .idle:
            bodyNode.fillColor = NSColor.systemOrange.withAlphaComponent(0.92)
            faceNode.text = "Joey"
            bodyNode.run(.repeatForever(.sequence([
                .scale(to: 1.04, duration: 1.2),
                .scale(to: 1.0, duration: 1.2)
            ])))

        case .sweating:
            bodyNode.fillColor = NSColor.systemRed.withAlphaComponent(0.88)
            faceNode.text = "Hot!"
            addSweatDrops()
            bodyNode.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 2, duration: 0.15),
                .moveBy(x: 0, y: -2, duration: 0.15)
            ])))

        case .tired:
            bodyNode.fillColor = NSColor.systemTeal.withAlphaComponent(0.85)
            faceNode.text = "Zzz"
            faceNode.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.45, duration: 0.8),
                .fadeAlpha(to: 1.0, duration: 0.8)
            ])))
            bodyNode.run(.repeatForever(.sequence([
                .scale(to: 0.94, duration: 1.5),
                .scale(to: 1.0, duration: 1.5)
            ])))

        case .carryingTrash:
            bodyNode.fillColor = NSColor.systemGreen.withAlphaComponent(0.88)
            faceNode.text = "Trash"
            addTrashBag()
            bodyNode.run(.repeatForever(.sequence([
                .rotate(byAngle: 0.08, duration: 0.4),
                .rotate(byAngle: -0.16, duration: 0.8),
                .rotate(byAngle: 0.08, duration: 0.4)
            ])))
        }
    }

    private func addSweatDrops() {
        for offset in [-18.0, 18.0] {
            let drop = SKShapeNode(circleOfRadius: 4)
            drop.fillColor = NSColor.systemCyan
            drop.strokeColor = .clear
            drop.position = CGPoint(x: offset, y: 24)
            effectNode.addChild(drop)
            drop.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: -10, duration: 0.35),
                .moveBy(x: 0, y: 10, duration: 0.01)
            ])))
        }
    }

    private func addTrashBag() {
        let bag = SKShapeNode(rectOf: CGSize(width: 18, height: 22), cornerRadius: 3)
        bag.fillColor = NSColor.systemGray
        bag.strokeColor = NSColor.darkGray
        bag.position = CGPoint(x: 30, y: -8)
        effectNode.addChild(bag)
    }
}
