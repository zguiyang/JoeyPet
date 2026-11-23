import AppKit
import SpriteKit

/// Debug-only 4×3 grid used to review the twelve V0.1 poses on real assets.
/// Launch with `-JoeyPetDebugPoses`; keys 1/2/3 switch the size tier.
@MainActor
final class JoeyPosePreviewScene: SKScene {
    private let package: JoeyAssetPackage
    private var sizeID: String
    private var characters: [JoeyCharacterNode] = []
    private var sizeLabel: SKLabelNode?

    private let columns = 4
    private let rows = 3
    private let cellSize = CGSize(width: 280, height: 330)

    private static let names: [String: String] = [
        "sit": "坐着",
        "look": "抬头看",
        "sign": "举牌",
        "stretch": "伸展",
        "happy": "开心",
        "sleep": "睡觉",
        "groom": "理毛",
        "yawn": "打哈欠",
        "doze": "打盹",
        "peek": "探头",
        "step": "走一步",
        "carry": "叼叶子"
    ]

    init(size: CGSize, package: JoeyAssetPackage, sizeID: String? = nil) {
        self.package = package
        self.sizeID = sizeID ?? package.defaultSizeSpec.id
        super.init(size: size)
        backgroundColor = NSColor(srgbRed: 0.968, green: 0.953, blue: 0.922, alpha: 1)
        scaleMode = .aspectFit
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func didMove(to view: SKView) {
        rebuild()
    }

    override func keyDown(with event: NSEvent) {
        switch event.charactersIgnoringModifiers {
        case "1": applySize(id: "s")
        case "2": applySize(id: "m")
        case "3": applySize(id: "l")
        default: super.keyDown(with: event)
        }
    }

    private func applySize(id: String) {
        guard package.sizeSpec(id: id) != nil else { return }
        sizeID = id
        characters.forEach { $0.applySize(id: id) }
        updateSizeLabel()
    }

    private func rebuild() {
        removeAllChildren()
        characters.removeAll()

        let poses = self.package.manifest.poses.map(\.id)
        for (index, poseID) in poses.enumerated() {
            let column = index % columns
            let row = index / columns
            let visualRow = rows - 1 - row

            let cell = SKShapeNode(rectOf: cellSize, cornerRadius: 14)
            cell.position = CGPoint(
                x: CGFloat(column) * cellSize.width + cellSize.width / 2,
                y: CGFloat(visualRow) * cellSize.height + cellSize.height / 2 + 16
            )
            cell.fillColor = NSColor(srgbRed: 0.988, green: 0.980, blue: 0.957, alpha: 0.9)
            cell.strokeColor = NSColor(srgbRed: 0.780, green: 0.741, blue: 0.690, alpha: 0.35)
            cell.lineWidth = 1
            addChild(cell)

            let character = JoeyCharacterNode(package: package, sizeID: sizeID, reduceMotion: true)
            character.position = CGPoint(
                x: cell.position.x,
                y: CGFloat(visualRow) * cellSize.height + 64
            )
            addChild(character)
            character.applyPose(poseID)
            characters.append(character)

            let idLabel = SKLabelNode(fontNamed: "Menlo")
            idLabel.text = poseID
            idLabel.fontSize = 12
            idLabel.fontColor = NSColor(srgbRed: 0.310, green: 0.427, blue: 0.329, alpha: 1)
            idLabel.verticalAlignmentMode = .baseline
            idLabel.position = CGPoint(x: cell.position.x, y: cell.position.y - cellSize.height / 2 + 36)
            addChild(idLabel)

            let nameLabel = SKLabelNode(fontNamed: "PingFangSC-Regular")
            nameLabel.text = Self.names[poseID] ?? poseID
            nameLabel.fontSize = 13
            nameLabel.fontColor = NSColor(srgbRed: 0.247, green: 0.227, blue: 0.208, alpha: 1)
            nameLabel.verticalAlignmentMode = .baseline
            nameLabel.position = CGPoint(x: cell.position.x, y: cell.position.y - cellSize.height / 2 + 18)
            addChild(nameLabel)
        }

        let title = SKLabelNode(fontNamed: "PingFangSC-Semibold")
        title.text = "JoeyPet · 12 姿态预览"
        title.fontSize = 18
        title.fontColor = NSColor(srgbRed: 0.247, green: 0.227, blue: 0.208, alpha: 1)
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: 28, y: size.height - 30)
        addChild(title)

        let hint = SKLabelNode(fontNamed: "PingFangSC-Regular")
        hint.text = "1 / 2 / 3 切换尺寸"
        hint.fontSize = 12
        hint.fontColor = NSColor(srgbRed: 0.431, green: 0.392, blue: 0.349, alpha: 1)
        hint.horizontalAlignmentMode = .right
        hint.position = CGPoint(x: size.width - 28, y: size.height - 30)
        addChild(hint)

        let sizeCaption = SKLabelNode(fontNamed: "Menlo")
        sizeCaption.fontSize = 12
        sizeCaption.fontColor = NSColor(srgbRed: 0.310, green: 0.427, blue: 0.329, alpha: 1)
        sizeCaption.horizontalAlignmentMode = .right
        sizeCaption.position = CGPoint(x: size.width - 28, y: size.height - 48)
        sizeLabel = sizeCaption
        addChild(sizeCaption)
        updateSizeLabel()
    }

    private func updateSizeLabel() {
        guard let spec = package.sizeSpec(id: sizeID) else { return }
        let factor = Double(spec.w) / Double(package.manifest.canvas.w)
        sizeLabel?.text = String(
            format: "%@ · %d × %d · %.3f×",
            spec.id,
            spec.w,
            spec.h,
            factor
        )
    }
}
