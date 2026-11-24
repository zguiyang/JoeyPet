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
    }

    private static let blinkSuppressedPoses: Set<String> = [
        "sign", "stretch", "happy", "wave", "sleep", "groom", "yawn", "peek"
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
        startBreath()
        startTail()
        scheduleBlink()
        scheduleEarTwitch()
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

    /// Pose-specific breath: sit / look / stretch each follow their frame sheet.
    private var breathProfile: (duration: TimeInterval, peakScale: CGFloat, tiltDegrees: CGFloat) {
        let spec = package.ambient("breathe")
        switch poseID {
        case "look":
            // docs/reference/joeypet-look-frames-v0.html
            return (5.4, 1.028, 0.6)
        case "stretch":
            // docs/reference/joeypet-stretch-frames-v0.html
            return (6.0, 1.032, 0.2)
        default:
            let isSleeping = poseID == "sleep" || poseID == "doze"
            let milliseconds = isSleeping ? (spec?.sleepMs ?? 6000) : (spec?.loopMs ?? 4800)
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

        // Look keeps a quieter wag so companionship does not steal focus
        // (joeypet-look-frames-v0.html peaks near ±5°).
        let degreeScale: CGFloat = poseID == "look" ? 5.0 / 12.0 : 1
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
        layerPivots["tail"]?.removeAction(forKey: ActionKey.tail)
        layerPivots["ears"]?.removeAction(forKey: ActionKey.earAngle)
        layerPivots["frontArm"]?.removeAction(forKey: ActionKey.wave)
        layerPivots["frontArm"]?.removeAction(forKey: ActionKey.stretchReach)
        layerPivots["backArm"]?.removeAction(forKey: ActionKey.stretchReach)
        removeAction(forKey: ActionKey.blink)
        removeAction(forKey: ActionKey.ear)

        breathPivot.xScale = 1
        breathPivot.yScale = 1
        breathPivot.zRotation = 0
        posePivot.position = restPosePivotPosition
        posePivot.zRotation = restPosePivotRotation
        layerPivots["tail"]?.zRotation = 0
        layerPivots["ears"]?.zRotation = 0
        layerPivots["frontArm"]?.zRotation = 0
        layerPivots["backArm"]?.zRotation = 0
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
