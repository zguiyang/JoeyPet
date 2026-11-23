import AppKit
import SpriteKit

/// Desktop scene for the layered V0.1 pet. It only renders poses; priority,
/// timers and product state live in `PetRuntime`.
@MainActor
final class JoeyDesktopScene: SKScene, PetPoseRendering {
    private let package: JoeyAssetPackage
    private let character: JoeyCharacterNode

    var skScene: SKScene { self }
    /// Exposed for the geometry test; the character is otherwise private.
    var fittedScale: CGFloat { character.xScale }

    init(size: CGSize, package: JoeyAssetPackage, sizeID: String? = nil) {
        self.package = package
        character = JoeyCharacterNode(
            package: package,
            sizeID: sizeID ?? package.defaultSizeSpec.id
        )

        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        addChild(character)
        fitCharacter()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func didChangeSize(_ oldSize: NSSize) {
        super.didChangeSize(oldSize)
        fitCharacter()
    }

    func show(pose: PetPose) {
        character.applyPose(pose.rawValue)
    }

    func setReduceMotion(_ enabled: Bool) {
        character.setReduceMotion(enabled)
    }

    /// Fits the 168×210 default sprite inside the current panel. PR4 replaces the
    /// panel size itself; until then this keeps the layered pet fully visible.
    private func fitCharacter() {
        guard size.width > 0, size.height > 0 else { return }

        let spec = package.defaultSizeSpec
        let canvas = package.manifest.canvas
        let fit = min(
            size.width / CGFloat(spec.w),
            size.height / CGFloat(spec.h)
        )
        // `setScale` is absolute, so include the size tier's own canvas scale.
        let totalScale = CGFloat(spec.w) / CGFloat(canvas.w) * fit
        character.setScale(totalScale)

        character.position = CGPoint(
            x: size.width / 2,
            y: CGFloat(canvas.h - canvas.anchor[1]) * totalScale
        )
    }
}
