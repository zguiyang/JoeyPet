import AppKit
import Foundation
import SpriteKit

/// Optional colour wash for the layered pet. The desktop pet uses `.none`;
/// the room applies a dusk tint so the same artwork sits in the dim light.
struct JoeyPetTint {
    let color: NSColor
    let factor: CGFloat

    static let none = JoeyPetTint(color: .clear, factor: 0)
}

/// Layered Joey renderer built from the V0.1 atlas.
///
/// Coordinate contract: the node origin is the canvas anchor (feet), so a parent
/// places it like a normal SpriteKit node. Layer textures are full-canvas and
/// stacked in manifest order; tail and ears rotate around their own roots, while
/// the pose transform rotates everything except the shadow.
@MainActor
final class JoeyCharacterNode: SKNode {
    private enum ActionKey {
        static let breath = "joey.breath"
        static let tail = "joey.tail"
        static let blink = "joey.blink"
        static let ear = "joey.ear"
        static let earAngle = "joey.earAngle"
    }

    private static let blinkSuppressedPoses: Set<String> = [
        "sign", "stretch", "happy", "sleep", "groom", "yawn", "peek"
    ]
    private static let earSuppressedPoses: Set<String> = [
        "sign", "stretch", "happy", "sleep", "groom", "yawn", "peek"
    ]

    private let package: JoeyAssetPackage
    private let canvas: CGSize
    private let anchor: CGPoint
    private let breathAnchor: CGPoint
    private let earAnchor: CGPoint
    private let tailAnchor: CGPoint
    private let layerBasePosition: CGPoint

    private let breathPivot = SKNode()
    private let posePivot = SKNode()
    private let layerRoot = SKNode()
    private let shadowNode = SKSpriteNode()
    private let fallbackNode = SKSpriteNode()
    private var layerSprites: [String: SKSpriteNode] = [:]
    private var layerPivots: [String: SKNode] = [:]

    private var currentFaceTexture: SKTexture?
    private var blinkTextures: [SKTexture] = []
    private var tint: JoeyPetTint = .none

    private(set) var poseID: String?
    private(set) var sizeID: String
    private(set) var isReduceMotionEnabled: Bool

    init(
        package: JoeyAssetPackage,
        sizeID: String? = nil,
        reduceMotion: Bool? = nil
    ) {
        self.package = package

        let manifest = package.manifest
        canvas = CGSize(width: manifest.canvas.w, height: manifest.canvas.h)
        anchor = CGPoint(x: manifest.canvas.anchor[0], y: manifest.canvas.anchor[1])

        let render = manifest.render
        func svgPoint(_ key: String, fallback: CGPoint) -> CGPoint {
            guard let values = render?.anchors[key], values.count == 2 else { return fallback }
            return CGPoint(x: values[0], y: values[1])
        }

        let breathSVG = svgPoint("breath", fallback: CGPoint(x: 160, y: 340))
        let earSVG = svgPoint("ear", fallback: CGPoint(x: 160, y: 150))
        let tailSVG = svgPoint("tail", fallback: CGPoint(x: 250, y: 286))

        breathAnchor = CGPoint(x: breathSVG.x - anchor.x, y: anchor.y - breathSVG.y)
        earAnchor = CGPoint(x: earSVG.x - anchor.x, y: anchor.y - earSVG.y)
        tailAnchor = CGPoint(x: tailSVG.x - anchor.x, y: anchor.y - tailSVG.y)
        layerBasePosition = CGPoint(x: -anchor.x, y: anchor.y - canvas.height)

        let resolvedSize = sizeID.flatMap(package.sizeSpec(id:)) ?? package.defaultSizeSpec
        self.sizeID = resolvedSize.id
        isReduceMotionEnabled = reduceMotion
            ?? NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        super.init()

        configureLayers()
        applySize(id: resolvedSize.id)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    // MARK: - Public API

    /// Hard-switches pose composition. Pose transitions are coordinated by the
    /// runtime; this node only renders the requested pose.
    func applyPose(_ id: String) {
        guard id != poseID else { return }
        poseID = id

        cancelAmbient()
        guard let layers = package.manifest.render?.poseLayers[id] else {
            showFallback(poseID: id)
            return
        }

        applyPoseTransform(layers: layers)

        var bodyFound = false
        var faceFound = false
        for layer in JoeyManifestValidator.expectedLayerOrder {
            let assetID = assetID(for: layer, in: layers)
            let texture = assetID.flatMap(package.layerTexture(assetID:))

            if layer == "shadow" {
                shadowNode.texture = texture
                shadowNode.isHidden = texture == nil
                continue
            }

            guard let sprite = layerSprites[layer] else { continue }
            sprite.texture = texture
            setLayerVisible(layer, texture != nil)

            if layer == "body", texture != nil { bodyFound = true }
            if layer == "face", texture != nil { faceFound = true }
        }

        guard bodyFound, faceFound else {
            showFallback(poseID: id)
            return
        }

        fallbackNode.isHidden = true
        shadowNode.isHidden = false

        let faceAssetID = layers.face
        currentFaceTexture = faceAssetID.flatMap(package.layerTexture(assetID:))
        blinkTextures = [2, 3].compactMap { frame in
            faceAssetID.flatMap { package.layerTexture(assetID: "\($0).blink\(frame)") }
        }

        startAmbientIfNeeded()
    }

    func applySize(id: String) {
        guard let spec = package.sizeSpec(id: id) else { return }
        sizeID = spec.id
        setScale(CGFloat(spec.w) / canvas.width)
    }

    func setReduceMotion(_ enabled: Bool) {
        guard enabled != isReduceMotionEnabled else { return }
        isReduceMotionEnabled = enabled
        if enabled {
            cancelAmbient()
        } else {
            startAmbientIfNeeded()
        }
    }

    /// Applies a colour wash to every fur/face/arm layer. The shadow is left
    /// neutral so the pet still sits on the ground.
    func setTint(_ tint: JoeyPetTint) {
        guard tint.color != self.tint.color || tint.factor != self.tint.factor else { return }
        self.tint = tint
        applyTint()
    }

    /// Whether a layer (including pivot-backed ears and tail) is drawn.
    func isLayerVisible(_ layer: String) -> Bool {
        guard let sprite = layerSprites[layer] else { return false }
        if let pivot = layerPivots[layer] {
            return !pivot.isHidden && !sprite.isHidden
        }
        return !sprite.isHidden
    }

    // MARK: - Node setup

    private func configureLayers() {
        breathPivot.position = breathAnchor
        addChild(breathPivot)

        shadowNode.anchorPoint = .zero
        shadowNode.size = canvas
        shadowNode.position = layerBasePosition - breathAnchor
        shadowNode.zPosition = 0
        shadowNode.texture = package.layerTexture(assetID: "shadow.default")
        shadowNode.isHidden = shadowNode.texture == nil
        breathPivot.addChild(shadowNode)

        breathPivot.addChild(posePivot)
        posePivot.addChild(layerRoot)

        for (index, layer) in JoeyManifestValidator.expectedLayerOrder.enumerated() where layer != "shadow" {
            let sprite = SKSpriteNode()
            sprite.anchorPoint = .zero
            sprite.size = canvas
            sprite.isHidden = true

            if let pivotAnchor = pivotAnchor(for: layer) {
                let pivot = SKNode()
                pivot.position = pivotAnchor
                pivot.zPosition = CGFloat(index)
                sprite.position = layerBasePosition - pivotAnchor
                // Pivot layers are hidden through their pivot, so the sprite
                // itself must start visible or it would never draw.
                sprite.isHidden = false
                pivot.addChild(sprite)
                layerRoot.addChild(pivot)
                layerPivots[layer] = pivot
            } else {
                sprite.position = layerBasePosition
                sprite.zPosition = CGFloat(index)
                layerRoot.addChild(sprite)
            }

            layerSprites[layer] = sprite
        }

        fallbackNode.anchorPoint = .zero
        fallbackNode.size = canvas
        fallbackNode.position = layerBasePosition - breathAnchor
        fallbackNode.zPosition = 1
        fallbackNode.isHidden = true
        breathPivot.addChild(fallbackNode)

        applyTint()
    }

    private func applyTint() {
        let factor = tint.factor > 0 ? min(max(tint.factor, 0), 1) : 0
        let color = factor > 0 ? tint.color : .clear

        for sprite in layerSprites.values {
            sprite.color = color
            sprite.colorBlendFactor = factor
        }
        fallbackNode.color = color
        fallbackNode.colorBlendFactor = factor
    }

    private func pivotAnchor(for layer: String) -> CGPoint? {
        switch layer {
        case "tail": tailAnchor
        case "ears": earAnchor
        default: nil
        }
    }

    // MARK: - Pose composition

    private func applyPoseTransform(layers: JoeyPoseLayers) {
        let pivotSVG = layers.pivot.flatMap { values -> CGPoint? in
            guard values.count == 2 else { return nil }
            return CGPoint(x: values[0], y: values[1])
        } ?? CGPoint(x: 160, y: 340)

        let pivot = CGPoint(x: pivotSVG.x - anchor.x, y: anchor.y - pivotSVG.y)
        posePivot.position = pivot - breathAnchor
        posePivot.zRotation = -CGFloat(layers.rotate ?? 0) * .pi / 180
        layerRoot.position = CGPoint(
            x: -pivot.x + CGFloat(layers.translateX ?? 0),
            y: -pivot.y - CGFloat(layers.translateY ?? 0)
        )
    }

    private func assetID(for layer: String, in layers: JoeyPoseLayers) -> String? {
        switch layer {
        case "shadow": layers.shadow
        case "tail": layers.tail
        case "body": layers.body
        case "ears": layers.ears
        case "backArm": layers.backArm
        case "face": layers.face
        case "frontArm": layers.frontArm
        case "prop": layers.prop
        default: nil
        }
    }

    private func setLayerVisible(_ layer: String, _ visible: Bool) {
        if let pivot = layerPivots[layer] {
            pivot.isHidden = !visible
        } else {
            layerSprites[layer]?.isHidden = !visible
        }
    }

    /// Whole-pose PNG fallback: transforms are already baked into the image.
    private func showFallback(poseID: String) {
        for layer in JoeyManifestValidator.expectedLayerOrder where layer != "shadow" {
            setLayerVisible(layer, false)
        }
        shadowNode.isHidden = true
        posePivot.position = .zero
        posePivot.zRotation = 0
        layerRoot.position = .zero
        currentFaceTexture = nil
        blinkTextures = []

        fallbackNode.texture = package.poseTexture(poseID: poseID) ?? package.poseTexture(poseID: "sit")
        fallbackNode.isHidden = fallbackNode.texture == nil
        startAmbientIfNeeded()
    }

    // MARK: - Ambient motion

    private func startAmbientIfNeeded() {
        guard !isReduceMotionEnabled, poseID != nil else { return }
        startBreath()
        startTail()
        scheduleBlink()
        scheduleEarTwitch()
    }

    private var breathDuration: TimeInterval {
        let spec = package.ambient("breathe")
        let isSleeping = poseID == "sleep" || poseID == "doze"
        let milliseconds = isSleeping ? (spec?.sleepMs ?? 6000) : (spec?.loopMs ?? 4800)
        return TimeInterval(milliseconds) / 1000
    }

    private func startBreath() {
        let spec = package.ambient("breathe")
        let targetScale = CGFloat(spec?.scale ?? 1.012)
        let half = breathDuration / 2

        breathPivot.setScale(1)
        breathPivot.removeAction(forKey: ActionKey.breath)

        let inhale = SKAction.scale(to: targetScale, duration: half)
        inhale.timingMode = .easeInEaseOut
        let exhale = SKAction.scale(to: 1, duration: half)
        exhale.timingMode = .easeInEaseOut
        breathPivot.run(.repeatForever(.sequence([inhale, exhale])), withKey: ActionKey.breath)
    }

    private func startTail() {
        guard let pivot = layerPivots["tail"], !pivot.isHidden else { return }
        guard let spec = package.ambient("tail"),
              case let .single(degrees)? = spec.degrees
        else { return }

        let amplitude = CGFloat(degrees) * .pi / 180
        let quarter = breathDuration / 4

        pivot.zRotation = 0
        pivot.removeAction(forKey: ActionKey.tail)

        let right = SKAction.rotate(toAngle: amplitude, duration: quarter, shortestUnitArc: true)
        right.timingMode = .easeInEaseOut
        let left = SKAction.rotate(toAngle: -amplitude, duration: quarter * 2, shortestUnitArc: true)
        left.timingMode = .easeInEaseOut
        let settle = SKAction.rotate(toAngle: 0, duration: quarter, shortestUnitArc: true)
        settle.timingMode = .easeInEaseOut

        pivot.run(
            .repeatForever(.sequence([right, left, settle])),
            withKey: ActionKey.tail
        )
    }

    private var canBlink: Bool {
        guard !blinkTextures.isEmpty, let poseID else { return false }
        return !Self.blinkSuppressedPoses.contains(poseID)
    }

    private func scheduleBlink() {
        guard canBlink else { return }

        let range = package.ambient("blink")?.everyMs ?? [2500, 6000]
        let lowest = Double(min(range.first ?? 2500, range.last ?? 6000)) / 1000
        let highest = Double(max(range.first ?? 2500, range.last ?? 6000)) / 1000

        let wait = SKAction.wait(forDuration: .random(in: lowest...highest))
        let fire = SKAction.run { [weak self] in self?.playBlink() }
        removeAction(forKey: ActionKey.blink)
        run(.sequence([wait, fire]), withKey: ActionKey.blink)
    }

    private func playBlink() {
        guard canBlink,
              let faceSprite = layerSprites["face"],
              !faceSprite.isHidden,
              blinkTextures.count >= 2
        else {
            scheduleBlink()
            return
        }

        let duration = TimeInterval(package.ambient("blink")?.durationMs ?? 180) / 1000
        let frameDuration = duration / 2

        let blink = SKAction.sequence([
            .run { faceSprite.texture = self.blinkTextures[0] },
            .wait(forDuration: frameDuration),
            .run { faceSprite.texture = self.blinkTextures[1] },
            .wait(forDuration: frameDuration),
            .run {
                faceSprite.texture = self.currentFaceTexture
                self.scheduleBlink()
            }
        ])
        run(blink, withKey: ActionKey.blink)
    }

    private var canTwitchEars: Bool {
        guard layerPivots["ears"]?.isHidden == false, let poseID else { return false }
        return !Self.earSuppressedPoses.contains(poseID)
    }

    private func scheduleEarTwitch() {
        guard canTwitchEars else { return }

        let range = package.ambient("ear")?.everyMs ?? [12000, 35000]
        let lowest = Double(min(range.first ?? 12000, range.last ?? 35000)) / 1000
        let highest = Double(max(range.first ?? 12000, range.last ?? 35000)) / 1000

        let wait = SKAction.wait(forDuration: .random(in: lowest...highest))
        let fire = SKAction.run { [weak self] in self?.playEarTwitch() }
        removeAction(forKey: ActionKey.ear)
        run(.sequence([wait, fire]), withKey: ActionKey.ear)
    }

    private func playEarTwitch() {
        guard canTwitchEars, let pivot = layerPivots["ears"] else {
            scheduleEarTwitch()
            return
        }

        let degrees: (CGFloat, CGFloat)
        if case let .range(lower, upper)? = package.ambient("ear")?.degrees {
            degrees = (CGFloat(lower), CGFloat(upper))
        } else {
            degrees = (-7, 4)
        }

        let step = TimeInterval(package.ambient("ear")?.durationMs ?? 240) / 1000 / 3
        let first = SKAction.rotate(toAngle: -degrees.0 * .pi / 180, duration: step, shortestUnitArc: true)
        let second = SKAction.rotate(toAngle: -degrees.1 * .pi / 180, duration: step, shortestUnitArc: true)
        let third = SKAction.rotate(toAngle: 0, duration: step, shortestUnitArc: true)

        pivot.run(.sequence([first, second, third]), withKey: ActionKey.earAngle)
        scheduleEarTwitch()
    }

    private func cancelAmbient() {
        breathPivot.removeAction(forKey: ActionKey.breath)
        layerPivots["tail"]?.removeAction(forKey: ActionKey.tail)
        layerPivots["ears"]?.removeAction(forKey: ActionKey.earAngle)
        removeAction(forKey: ActionKey.blink)
        removeAction(forKey: ActionKey.ear)

        breathPivot.setScale(1)
        layerPivots["tail"]?.zRotation = 0
        layerPivots["ears"]?.zRotation = 0
        layerSprites["face"]?.texture = currentFaceTexture
    }
}

private extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}
