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
        static let wave = "joey.wave"
        static let stretchReach = "joey.stretchReach"
        static let happy = "joey.happy"
        static let dozeLoop = "joey.dozeLoop"
        static let dozeMicro = "joey.dozeMicro"
        static let dozeHead = "joey.dozeHead"
        static let sleepLoop = "joey.sleepLoop"
        static let sleepMicro = "joey.sleepMicro"
        static let sleepHead = "joey.sleepHead"
        static let sleepEar = "joey.sleepEar"
        static let yawn = "joey.yawn"
        static let carryLoop = "joey.carryLoop"
        static let carryLeaf = "joey.carryLeaf"
        static let groom = "joey.groom"
    }

    private static let blinkSuppressedPoses: Set<String> = [
        "sign", "stretch", "happy", "wave", "sleep", "doze", "groom", "yawn", "peek"
    ]
    private static let earSuppressedPoses: Set<String> = [
        "sign", "stretch", "happy", "wave", "sleep", "groom", "yawn", "peek"
    ]

    private let package: JoeyAssetPackage
    private let canvas: CGSize
    private let anchor: CGPoint
    private let breathAnchor: CGPoint
    private let earAnchor: CGPoint
    private let tailAnchor: CGPoint
    private let frontArmAnchor: CGPoint
    private let backArmAnchor: CGPoint
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
    private var contentScale: CGFloat = 1
    private var restPosePivotPosition: CGPoint = .zero
    private var restPosePivotRotation: CGFloat = 0

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
        let shoulderRightSVG = svgPoint("shoulderRight", fallback: CGPoint(x: 230, y: 254))
        let shoulderLeftSVG = svgPoint("shoulderLeft", fallback: CGPoint(x: 90, y: 254))

        breathAnchor = CGPoint(x: breathSVG.x - anchor.x, y: anchor.y - breathSVG.y)
        earAnchor = CGPoint(x: earSVG.x - anchor.x, y: anchor.y - earSVG.y)
        tailAnchor = CGPoint(x: tailSVG.x - anchor.x, y: anchor.y - tailSVG.y)
        frontArmAnchor = CGPoint(
            x: shoulderRightSVG.x - anchor.x,
            y: anchor.y - shoulderRightSVG.y
        )
        backArmAnchor = CGPoint(
            x: shoulderLeftSVG.x - anchor.x,
            y: anchor.y - shoulderLeftSVG.y
        )
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
        startWaveIfNeeded()
        startStretchReachIfNeeded()
        startHappyCelebrationIfNeeded()
        startYawnIfNeeded()
        startGroomIfNeeded()
    }

    func applySize(id: String) {
        guard let spec = package.sizeSpec(id: id) else { return }
        sizeID = spec.id
        setContentScale(CGFloat(spec.w) / canvas.width)
    }

    /// Absolute uniform scale. Used by the desktop scene fit pass.
    func setContentScale(_ scale: CGFloat) {
        contentScale = abs(scale)
        applyContentTransform()
    }

    func setReduceMotion(_ enabled: Bool) {
        guard enabled != isReduceMotionEnabled else { return }
        isReduceMotionEnabled = enabled
        if enabled {
            cancelAmbient()
        } else {
            startAmbientIfNeeded()
            startWaveIfNeeded()
            startStretchReachIfNeeded()
            startHappyCelebrationIfNeeded()
            startYawnIfNeeded()
            startGroomIfNeeded()
        }
    }

    private func applyContentTransform() {
        xScale = contentScale
        yScale = contentScale
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
        case "frontArm": frontArmAnchor
        case "backArm": backArmAnchor
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
        restPosePivotPosition = posePivot.position
        restPosePivotRotation = posePivot.zRotation
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
        // Happy / yawn / groom are one-shots, not breath loops.
        guard poseID != "happy", poseID != "yawn", poseID != "groom" else { return }
        if poseID == "doze" {
            // docs/reference/joeypet-doze-spritesheet-v0.svg — breath+sway loop + random micro.
            startDozeLoop()
            scheduleDozeMicroAction()
            return
        }
        if poseID == "sleep" {
            // docs/reference/joeypet-sleep-spritesheet-v0.svg — quieter breath + rare micros.
            startSleepLoop()
            scheduleSleepMicroAction()
            return
        }
        if poseID == "carry" {
            // docs/reference/joeypet-carry-spritesheet-v0.svg — soft breath + rare leaf nudge.
            startCarryLoop()
            startTail()
            scheduleBlink()
            scheduleCarryLeafNudge()
            return
        }
        startBreath()
        startTail()
        scheduleBlink()
        scheduleEarTwitch()
    }

    /// Post-break leaf hold from the accepted carry spritesheet (A: 8 frames / 3.6 s).
    /// Peak scaleY 1.018, sway ≤ ±0.2°. Leaf tip wobble is a separate rare micro.
    private func startCarryLoop() {
        breathPivot.removeAction(forKey: ActionKey.breath)
        breathPivot.removeAction(forKey: ActionKey.carryLoop)
        breathPivot.xScale = 1
        breathPivot.yScale = 1
        breathPivot.zRotation = 0

        let step: TimeInterval = 3.6 / 8
        let frames: [(rotationDegrees: CGFloat, scaleY: CGFloat)] = [
            (0, 1.000), (0, 1.005), (0.1, 1.012), (0.2, 1.018),
            (0.1, 1.010), (0, 1.004), (0, 1.001), (0, 1.000)
        ]

        var steps: [SKAction] = []
        for frame in frames {
            let rotate = SKAction.rotate(
                toAngle: frame.rotationDegrees * .pi / 180,
                duration: step,
                shortestUnitArc: true
            )
            rotate.timingMode = .easeInEaseOut
            let scale = SKAction.scaleY(to: frame.scaleY, duration: step)
            scale.timingMode = .easeInEaseOut
            steps.append(.group([rotate, scale]))
        }

        breathPivot.run(.repeatForever(.sequence(steps)), withKey: ActionKey.carryLoop)
    }

    /// Occasional leaf tip nudge (B: 12° → 10° → 14° → 12°).
    /// `prop.leaf` is a full-canvas layer without a stem pivot, so approximate the
    /// tip rotate with a tiny translation bob of the prop sprite.
    private func scheduleCarryLeafNudge() {
        guard poseID == "carry", !isReduceMotionEnabled else { return }

        let wait = SKAction.wait(forDuration: .random(in: 8...16))
        let fire = SKAction.run { [weak self] in self?.playCarryLeafNudge() }
        removeAction(forKey: ActionKey.carryLeaf)
        run(.sequence([wait, fire]), withKey: ActionKey.carryLeaf)
    }

    private func playCarryLeafNudge() {
        guard poseID == "carry",
              let prop = layerSprites["prop"],
              !prop.isHidden
        else {
            scheduleCarryLeafNudge()
            return
        }

        let rest = prop.position
        // ~2° tip around the mouth maps to a very small screen-space bob.
        let down = CGPoint(x: rest.x - 0.6, y: rest.y - 0.8)
        let up = CGPoint(x: rest.x + 0.6, y: rest.y + 0.8)

        let dip = SKAction.move(to: down, duration: 0.22)
        dip.timingMode = .easeInEaseOut
        let lift = SKAction.move(to: up, duration: 0.24)
        lift.timingMode = .easeInEaseOut
        let settle = SKAction.move(to: rest, duration: 0.26)
        settle.timingMode = .easeInEaseOut
        prop.run(.sequence([dip, lift, settle]), withKey: ActionKey.carryLeaf)
        scheduleCarryLeafNudge()
    }

    /// Shallow nap loop from the accepted doze spritesheet (A: 10 frames / 7.2 s).
    /// Sway ±1.1° on breathPivot; scaleY 1.000 → 1.011 → 0.989 → 1.000.
    private func startDozeLoop() {
        breathPivot.removeAction(forKey: ActionKey.breath)
        breathPivot.removeAction(forKey: ActionKey.dozeLoop)
        breathPivot.xScale = 1
        breathPivot.yScale = 1
        breathPivot.zRotation = 0

        let step: TimeInterval = 0.72
        let frames: [(rotationDegrees: CGFloat, scaleY: CGFloat)] = [
            (0, 1.000), (0.7, 1.007), (1.1, 1.011), (1.1, 1.011), (0.7, 1.007),
            (0, 1.000), (-0.7, 0.993), (-1.1, 0.989), (-1.1, 0.989), (-0.7, 0.993)
        ]

        var steps: [SKAction] = []
        for frame in frames {
            let rotate = SKAction.rotate(
                toAngle: frame.rotationDegrees * .pi / 180,
                duration: step,
                shortestUnitArc: true
            )
            rotate.timingMode = .easeInEaseOut
            let scale = SKAction.scaleY(to: frame.scaleY, duration: step)
            scale.timingMode = .easeInEaseOut
            steps.append(.group([rotate, scale]))
        }

        breathPivot.run(.repeatForever(.sequence(steps)), withKey: ActionKey.dozeLoop)
    }

    /// Occasional doze micro-actions (B rows): ear sway, head dip, tiny tail flick.
    private func scheduleDozeMicroAction() {
        guard poseID == "doze", !isReduceMotionEnabled else { return }

        let wait = SKAction.wait(forDuration: .random(in: 12...28))
        let fire = SKAction.run { [weak self] in self?.playDozeMicroAction() }
        removeAction(forKey: ActionKey.dozeMicro)
        run(.sequence([wait, fire]), withKey: ActionKey.dozeMicro)
    }

    private func playDozeMicroAction() {
        guard poseID == "doze", !isReduceMotionEnabled else { return }

        switch Int.random(in: 0...2) {
        case 0:
            playDozeEarSway()
        case 1:
            playDozeHeadDip()
        default:
            playDozeTailFlick()
        }
        scheduleDozeMicroAction()
    }

    private func playDozeEarSway() {
        guard let pivot = layerPivots["ears"], !pivot.isHidden else { return }
        // Spritesheet B1: 0 → −2.5° → +2.5° → 0
        let step: TimeInterval = 0.22
        let left = SKAction.rotate(toAngle: -2.5 * .pi / 180, duration: step, shortestUnitArc: true)
        left.timingMode = .easeInEaseOut
        let right = SKAction.rotate(toAngle: 2.5 * .pi / 180, duration: step, shortestUnitArc: true)
        right.timingMode = .easeInEaseOut
        let center = SKAction.rotate(toAngle: 0, duration: step, shortestUnitArc: true)
        center.timingMode = .easeInEaseOut
        pivot.run(.sequence([left, right, center]), withKey: ActionKey.earAngle)
    }

    private func playDozeHeadDip() {
        guard let face = layerSprites["face"], !face.isHidden else { return }
        // Spritesheet B2: face dips ~4 pt (SVG +Y); SpriteKit Y is up so subtract.
        let rest = face.position
        let light = CGPoint(x: rest.x, y: rest.y - 2.5)
        let deep = CGPoint(x: rest.x, y: rest.y - 4.0)
        let almost = CGPoint(x: rest.x, y: rest.y - 1.0)

        let down = SKAction.move(to: light, duration: 0.28)
        down.timingMode = .easeInEaseOut
        let deeper = SKAction.move(to: deep, duration: 0.28)
        deeper.timingMode = .easeInEaseOut
        let up = SKAction.move(to: almost, duration: 0.24)
        up.timingMode = .easeInEaseOut
        let settle = SKAction.move(to: rest, duration: 0.24)
        settle.timingMode = .easeInEaseOut
        face.run(.sequence([down, deeper, up, settle]), withKey: ActionKey.dozeHead)
    }

    private func playDozeTailFlick() {
        guard let pivot = layerPivots["tail"], !pivot.isHidden else { return }
        // Spritesheet B3: 0 → 3° → 1° → 0
        let out = SKAction.rotate(toAngle: 3 * .pi / 180, duration: 0.28, shortestUnitArc: true)
        out.timingMode = .easeInEaseOut
        let settle = SKAction.rotate(toAngle: 1 * .pi / 180, duration: 0.22, shortestUnitArc: true)
        settle.timingMode = .easeInEaseOut
        let rest = SKAction.rotate(toAngle: 0, duration: 0.22, shortestUnitArc: true)
        rest.timingMode = .easeInEaseOut
        pivot.run(.sequence([out, settle, rest]), withKey: ActionKey.tail)
    }

    /// Quiet-hours deep sleep from the accepted sleep spritesheet (A: 10 frames / 8.0 s).
    /// Peak scaleY 1.010, sway ≤ ±0.2°. Tail stays still; ears stay on baked splay.
    private func startSleepLoop() {
        breathPivot.removeAction(forKey: ActionKey.breath)
        breathPivot.removeAction(forKey: ActionKey.sleepLoop)
        breathPivot.xScale = 1
        breathPivot.yScale = 1
        breathPivot.zRotation = 0

        let step: TimeInterval = 0.8
        let frames: [(rotationDegrees: CGFloat, scaleY: CGFloat)] = [
            (0, 1.000), (0, 1.003), (0.1, 1.007), (0.2, 1.009), (0.1, 1.010),
            (0, 1.008), (-0.1, 1.005), (-0.2, 1.002), (-0.1, 0.999), (0, 1.000)
        ]

        var steps: [SKAction] = []
        for frame in frames {
            let rotate = SKAction.rotate(
                toAngle: frame.rotationDegrees * .pi / 180,
                duration: step,
                shortestUnitArc: true
            )
            rotate.timingMode = .easeInEaseOut
            let scale = SKAction.scaleY(to: frame.scaleY, duration: step)
            scale.timingMode = .easeInEaseOut
            steps.append(.group([rotate, scale]))
        }

        breathPivot.run(.repeatForever(.sequence(steps)), withKey: ActionKey.sleepLoop)
    }

    /// Rare sleep micros (B rows): ear settle, soft head dip. Longer gaps than doze.
    private func scheduleSleepMicroAction() {
        guard poseID == "sleep", !isReduceMotionEnabled else { return }

        let wait = SKAction.wait(forDuration: .random(in: 22...45))
        let fire = SKAction.run { [weak self] in self?.playSleepMicroAction() }
        removeAction(forKey: ActionKey.sleepMicro)
        run(.sequence([wait, fire]), withKey: ActionKey.sleepMicro)
    }

    private func playSleepMicroAction() {
        guard poseID == "sleep", !isReduceMotionEnabled else { return }

        if Bool.random() {
            playSleepEarSettle()
        } else {
            playSleepHeadDip()
        }
        scheduleSleepMicroAction()
    }

    private func playSleepEarSettle() {
        guard let pivot = layerPivots["ears"], !pivot.isHidden else { return }
        // ears.sleep already bakes ±11° splay; true per-ear deepen isn't available on one
        // texture. Approximate the B1 “settle” with a soft vertical dip of the ear layer.
        let rest = pivot.position
        let mid = CGPoint(x: rest.x, y: rest.y - 1.0)
        let deep = CGPoint(x: rest.x, y: rest.y - 1.8)

        let down = SKAction.move(to: mid, duration: 0.32)
        down.timingMode = .easeInEaseOut
        let deeper = SKAction.move(to: deep, duration: 0.28)
        deeper.timingMode = .easeInEaseOut
        let settle = SKAction.move(to: rest, duration: 0.36)
        settle.timingMode = .easeInEaseOut
        pivot.run(.sequence([down, deeper, settle]), withKey: ActionKey.sleepEar)
    }

    private func playSleepHeadDip() {
        guard let face = layerSprites["face"], !face.isHidden else { return }
        // Spritesheet B2: face/ears dip ~2.5 pt — quieter than doze.
        let rest = face.position
        let light = CGPoint(x: rest.x, y: rest.y - 1.5)
        let deep = CGPoint(x: rest.x, y: rest.y - 2.5)

        let down = SKAction.move(to: light, duration: 0.32)
        down.timingMode = .easeInEaseOut
        let deeper = SKAction.move(to: deep, duration: 0.28)
        deeper.timingMode = .easeInEaseOut
        let settle = SKAction.move(to: rest, duration: 0.36)
        settle.timingMode = .easeInEaseOut
        face.run(.sequence([down, deeper, settle]), withKey: ActionKey.sleepHead)
    }

    /// Quiet idle groom: soft ear-stroke on the raised front arm over ~2.8 s.
    /// Matches docs/reference/joeypet-groom-spritesheet-v0.svg (peak hold + light stroke).
    /// `arm.frontGroom` already bakes the raised paw; motion is a small shoulder wiggle.
    private func startGroomIfNeeded() {
        guard poseID == "groom" else { return }

        let pivot = layerPivots["frontArm"]
        pivot?.removeAction(forKey: ActionKey.groom)
        pivot?.zRotation = 0

        guard !isReduceMotionEnabled, let pivot, !pivot.isHidden else { return }

        let peak = CGFloat(package.ambient("groom")?.armDeg ?? -15) * .pi / 180
        let out = SKAction.rotate(toAngle: peak, duration: 0.35, shortestUnitArc: true)
        out.timingMode = .easeInEaseOut
        let back = SKAction.rotate(toAngle: peak * 0.35, duration: 0.4, shortestUnitArc: true)
        back.timingMode = .easeInEaseOut
        let again = SKAction.rotate(toAngle: peak, duration: 0.35, shortestUnitArc: true)
        again.timingMode = .easeInEaseOut
        let settle = SKAction.rotate(toAngle: 0, duration: 0.45, shortestUnitArc: true)
        settle.timingMode = .easeInEaseOut
        let hold = SKAction.wait(forDuration: 1.25)
        pivot.run(.sequence([out, back, again, hold, settle]), withKey: ActionKey.groom)
    }

    /// Wake / long-sit yawn: one-shot head tip-back over 1.8 s.
    /// Matches docs/reference/joeypet-yawn-spritesheet-v0.svg (base +2° → peak +3.8°).
    private func startYawnIfNeeded() {
        guard poseID == "yawn" else { return }

        breathPivot.removeAction(forKey: ActionKey.yawn)
        layerPivots["ears"]?.removeAction(forKey: ActionKey.yawn)
        breathPivot.xScale = 1
        breathPivot.yScale = 1
        breathPivot.zRotation = 0
        layerPivots["ears"]?.zRotation = 0

        guard !isReduceMotionEnabled else { return }

        // Manifest already applies rotate +2°; extra tip is up to +1.8° (SVG 2 → 3.8).
        // posePivot stores SVG rotate as negative SK angle, so deepen with negative breathPivot.
        let step: TimeInterval = 1.8 / 8
        let tilts: [CGFloat] = [0, -0.5, -1.5, -1.8, -1.0, -0.5, -0.1, 0]
        let earAngles: [CGFloat] = [0, 0, 1.0, 1.5, 0.6, 0, 0, 0]

        var bodySteps: [SKAction] = []
        for degrees in tilts {
            let rotate = SKAction.rotate(
                toAngle: degrees * .pi / 180,
                duration: step,
                shortestUnitArc: true
            )
            rotate.timingMode = .easeInEaseOut
            bodySteps.append(rotate)
        }
        breathPivot.run(.sequence(bodySteps), withKey: ActionKey.yawn)

        if let ears = layerPivots["ears"], !ears.isHidden {
            var earSteps: [SKAction] = []
            for degrees in earAngles {
                let rotate = SKAction.rotate(
                    toAngle: degrees * .pi / 180,
                    duration: step,
                    shortestUnitArc: true
                )
                rotate.timingMode = .easeInEaseOut
                earSteps.append(rotate)
            }
            ears.run(.sequence(earSteps), withKey: ActionKey.yawn)
        }
    }

    /// Greeting hold: rotate the raised front arm twice around the right shoulder.
    private func startWaveIfNeeded() {
        guard poseID == "wave",
              let pivot = layerPivots["frontArm"],
              !pivot.isHidden
        else { return }

        pivot.zRotation = 0
        pivot.removeAction(forKey: ActionKey.wave)
        guard !isReduceMotionEnabled else { return }

        let out = SKAction.rotate(toAngle: -14 * .pi / 180, duration: 0.28, shortestUnitArc: true)
        out.timingMode = .easeInEaseOut
        let back = SKAction.rotate(toAngle: 10 * .pi / 180, duration: 0.28, shortestUnitArc: true)
        back.timingMode = .easeInEaseOut
        let settle = SKAction.rotate(toAngle: 0, duration: 0.22, shortestUnitArc: true)
        settle.timingMode = .easeInEaseOut
        let oneWave = SKAction.sequence([out, back, settle])
        pivot.run(.sequence([oneWave, oneWave]), withKey: ActionKey.wave)
    }

    /// Recovery hold: both raised arms open a few more degrees with the breath.
    /// Matches docs/reference/joeypet-stretch-frames-v0.html (`--reach` ≤ 3.4°).
    private func startStretchReachIfNeeded() {
        guard poseID == "stretch" else { return }
        let front = layerPivots["frontArm"]
        let back = layerPivots["backArm"]
        front?.removeAction(forKey: ActionKey.stretchReach)
        back?.removeAction(forKey: ActionKey.stretchReach)
        front?.zRotation = 0
        back?.zRotation = 0
        guard !isReduceMotionEnabled else { return }

        let peak = 3.4 * CGFloat.pi / 180
        let half = breathDuration / 2

        func reachCycle(opening: CGFloat) -> SKAction {
            let out = SKAction.rotate(toAngle: opening, duration: half, shortestUnitArc: true)
            out.timingMode = .easeInEaseOut
            let back = SKAction.rotate(toAngle: 0, duration: half, shortestUnitArc: true)
            back.timingMode = .easeInEaseOut
            return .repeatForever(.sequence([out, back]))
        }

        front?.run(reachCycle(opening: peak), withKey: ActionKey.stretchReach)
        back?.run(reachCycle(opening: -peak), withKey: ActionKey.stretchReach)
    }

    /// Completed-break celebration: soft hop + squash over 2.6 s, then hold.
    /// Matches docs/reference/joeypet-happy-frames-v0.html (base lift -5 → peak -11).
    private func startHappyCelebrationIfNeeded() {
        guard poseID == "happy" else { return }

        posePivot.removeAction(forKey: ActionKey.happy)
        breathPivot.removeAction(forKey: ActionKey.happy)
        layerPivots["ears"]?.removeAction(forKey: ActionKey.happy)
        layerPivots["tail"]?.removeAction(forKey: ActionKey.happy)
        posePivot.position = restPosePivotPosition
        breathPivot.xScale = 1
        breathPivot.yScale = 1
        breathPivot.zRotation = 0
        layerPivots["ears"]?.zRotation = 0
        layerPivots["tail"]?.zRotation = 0

        guard !isReduceMotionEnabled else { return }

        // Manifest already applies translateY -5; extra hop is +6 pt (SVG -5 → -11).
        let rest = restPosePivotPosition
        let peak = CGPoint(x: rest.x, y: rest.y + 6)

        let rise = SKAction.move(to: peak, duration: 1.04)
        rise.timingMode = .easeOut
        let settle = SKAction.move(to: rest, duration: 1.56)
        settle.timingMode = .easeInEaseOut
        posePivot.run(.sequence([rise, settle]), withKey: ActionKey.happy)

        let squashUp = SKAction.scaleY(to: 1.012, duration: 1.04)
        squashUp.timingMode = .easeOut
        let squashDown = SKAction.scaleY(to: 1.0, duration: 1.56)
        squashDown.timingMode = .easeInEaseOut
        let tiltOut = SKAction.rotate(toAngle: 0.6 * .pi / 180, duration: 1.04, shortestUnitArc: true)
        tiltOut.timingMode = .easeOut
        let tiltBack = SKAction.rotate(toAngle: 0, duration: 1.56, shortestUnitArc: true)
        tiltBack.timingMode = .easeInEaseOut
        breathPivot.run(
            .sequence([
                .group([squashUp, tiltOut]),
                .group([squashDown, tiltBack])
            ]),
            withKey: ActionKey.happy
        )

        if let ears = layerPivots["ears"], !ears.isHidden {
            let left = SKAction.rotate(toAngle: -2.0 * .pi / 180, duration: 0.35, shortestUnitArc: true)
            left.timingMode = .easeInEaseOut
            let right = SKAction.rotate(toAngle: 1.6 * .pi / 180, duration: 0.35, shortestUnitArc: true)
            right.timingMode = .easeInEaseOut
            let center = SKAction.rotate(toAngle: 0, duration: 0.4, shortestUnitArc: true)
            center.timingMode = .easeInEaseOut
            ears.run(.sequence([left, right, center]), withKey: ActionKey.happy)
        }

        if let tail = layerPivots["tail"], !tail.isHidden {
            let out = SKAction.rotate(toAngle: 0.6 * .pi / 180, duration: 0.5, shortestUnitArc: true)
            out.timingMode = .easeInEaseOut
            let back = SKAction.rotate(toAngle: -2.0 * .pi / 180, duration: 0.7, shortestUnitArc: true)
            back.timingMode = .easeInEaseOut
            let settleTail = SKAction.rotate(toAngle: 0, duration: 0.6, shortestUnitArc: true)
            settleTail.timingMode = .easeInEaseOut
            tail.run(.sequence([out, back, settleTail]), withKey: ActionKey.happy)
        }
    }

    /// Pose-specific breath: sit / look / stretch / doze each follow their frame sheet.
    private var breathProfile: (duration: TimeInterval, peakScale: CGFloat, tiltDegrees: CGFloat) {
        let spec = package.ambient("breathe")
        switch poseID {
        case "look":
            // docs/reference/joeypet-look-frames-v0.html
            return (5.4, 1.028, 0.6)
        case "stretch":
            // docs/reference/joeypet-stretch-frames-v0.html
            return (6.0, 1.032, 0.2)
        case "doze":
            // docs/reference/joeypet-doze-spritesheet-v0.svg — used by startDozeLoop().
            return (7.2, 1.011, 1.1)
        case "sleep":
            // docs/reference/joeypet-sleep-spritesheet-v0.svg — used by startSleepLoop().
            return (8.0, 1.010, 0.2)
        case "carry":
            // docs/reference/joeypet-carry-spritesheet-v0.svg — used by startCarryLoop().
            return (3.6, 1.018, 0.2)
        default:
            let milliseconds = spec?.loopMs ?? 4800
            // docs/reference/joeypet-idle-breathing-frames-v0.html
            return (
                TimeInterval(milliseconds) / 1000,
                CGFloat(spec?.scale ?? 1.046),
                1.2
            )
        }
    }

    private var breathDuration: TimeInterval { breathProfile.duration }

    private func startBreath() {
        let profile = breathProfile
        let targetScale = profile.peakScale
        let tiltRadians = profile.tiltDegrees * .pi / 180
        let half = profile.duration / 2

        breathPivot.xScale = 1
        breathPivot.yScale = 1
        breathPivot.zRotation = 0
        breathPivot.removeAction(forKey: ActionKey.breath)

        let inhaleScale = SKAction.scaleY(to: targetScale, duration: half)
        inhaleScale.timingMode = .easeInEaseOut
        let inhaleTilt = SKAction.rotate(toAngle: -tiltRadians, duration: half, shortestUnitArc: true)
        inhaleTilt.timingMode = .easeInEaseOut
        let exhaleScale = SKAction.scaleY(to: 1, duration: half)
        exhaleScale.timingMode = .easeInEaseOut
        let exhaleTilt = SKAction.rotate(toAngle: 0, duration: half, shortestUnitArc: true)
        exhaleTilt.timingMode = .easeInEaseOut

        breathPivot.run(
            .repeatForever(
                .sequence([
                    .group([inhaleScale, inhaleTilt]),
                    .group([exhaleScale, exhaleTilt])
                ])
            ),
            withKey: ActionKey.breath
        )
    }

    private func startTail() {
        // Recovery stretch keeps the tail nearly still (domain ambient matrix).
        guard poseID != "stretch" else { return }
        guard let pivot = layerPivots["tail"], !pivot.isHidden else { return }
        guard let spec = package.ambient("tail"),
              case let .single(degrees)? = spec.degrees
        else { return }

        // Look / doze / carry keep quieter wags so they do not steal focus.
        let degreeScale: CGFloat = {
            switch poseID {
            case "look": return 5.0 / 12.0
            case "doze": return 1.5 / 12.0
            case "carry": return 2.0 / 12.0
            default: return 1
            }
        }()
        let amplitude = CGFloat(degrees) * degreeScale * .pi / 180
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

        var degrees: (CGFloat, CGFloat)
        if case let .range(lower, upper)? = package.ambient("ear")?.degrees {
            degrees = (CGFloat(lower), CGFloat(upper))
        } else {
            degrees = (-7, 4)
        }
        // Domain matrix: look ear amplitude halved vs sit.
        if poseID == "look" {
            degrees = (degrees.0 * 0.5, degrees.1 * 0.5)
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
        breathPivot.removeAction(forKey: ActionKey.happy)
        breathPivot.removeAction(forKey: ActionKey.dozeLoop)
        breathPivot.removeAction(forKey: ActionKey.sleepLoop)
        breathPivot.removeAction(forKey: ActionKey.carryLoop)
        breathPivot.removeAction(forKey: ActionKey.yawn)
        posePivot.removeAction(forKey: ActionKey.happy)
        layerPivots["tail"]?.removeAction(forKey: ActionKey.tail)
        layerPivots["tail"]?.removeAction(forKey: ActionKey.happy)
        layerPivots["ears"]?.removeAction(forKey: ActionKey.earAngle)
        layerPivots["ears"]?.removeAction(forKey: ActionKey.happy)
        layerPivots["ears"]?.removeAction(forKey: ActionKey.sleepEar)
        layerPivots["ears"]?.removeAction(forKey: ActionKey.yawn)
        layerPivots["frontArm"]?.removeAction(forKey: ActionKey.wave)
        layerPivots["frontArm"]?.removeAction(forKey: ActionKey.stretchReach)
        layerPivots["frontArm"]?.removeAction(forKey: ActionKey.groom)
        layerPivots["backArm"]?.removeAction(forKey: ActionKey.stretchReach)
        layerSprites["face"]?.removeAction(forKey: ActionKey.dozeHead)
        layerSprites["face"]?.removeAction(forKey: ActionKey.sleepHead)
        removeAction(forKey: ActionKey.blink)
        removeAction(forKey: ActionKey.ear)
        removeAction(forKey: ActionKey.dozeMicro)
        removeAction(forKey: ActionKey.sleepMicro)
        removeAction(forKey: ActionKey.carryLeaf)
        layerSprites["prop"]?.removeAction(forKey: ActionKey.carryLeaf)
        if let prop = layerSprites["prop"] {
            prop.position = layerBasePosition
        }

        breathPivot.xScale = 1
        breathPivot.yScale = 1
        breathPivot.zRotation = 0
        posePivot.position = restPosePivotPosition
        posePivot.zRotation = restPosePivotRotation
        layerPivots["tail"]?.zRotation = 0
        if let ears = layerPivots["ears"] {
            ears.removeAction(forKey: ActionKey.sleepEar)
            ears.zRotation = 0
            if let anchor = pivotAnchor(for: "ears") {
                ears.position = anchor
            }
        }
        layerPivots["frontArm"]?.zRotation = 0
        layerPivots["backArm"]?.zRotation = 0
        if let face = layerSprites["face"] {
            face.removeAction(forKey: ActionKey.dozeHead)
            face.removeAction(forKey: ActionKey.sleepHead)
            face.position = layerBasePosition
            face.texture = currentFaceTexture
        }
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
