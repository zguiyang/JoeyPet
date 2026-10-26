import AppKit
import CoreGraphics
import SpriteKit

// MARK: - Scene

/// Ambient SpriteKit layer for the Calm Space main window: sparse starfield, a few very
/// large soft ambience washes, and the layered abstract energy orb.
///
/// Two constraints shape the implementation:
///
/// 1. **The orb must survive every window size.** The whole composition is authored in
///    fixed "base units" (`Metrics.baseDiameter`) inside a single uniformly scaled root
///    node (`orbRoot`). A resize only changes that root's position/scale, so the sphere
///    can never become an ellipse and no texture is ever regenerated on resize.
/// 2. **Idle cost must stay near zero.** Rendering is capped at 30 FPS, all art is a
///    handful of Core Graphics textures baked once and cached (no shaders, no live blur,
///    no per-frame texture work), and every animation is an `SKAction`. Only four nodes
///    use tiny per-frame `customAction` math — one breathing driver plus the three orbit
///    particles — because those need phase continuity when the mode changes rhythm.
///
/// Because the project defaults to `MainActor` isolation this type is implicitly
/// main-actor isolated; it is marked explicitly to match the SpriteKit conventions in
/// `Pet/Sprite/PetScene.swift`.
@MainActor
final class CalmSpaceOrbScene: SKScene {

    // MARK: - Layout constants (base units)

    private enum Metrics {
        /// Points the orb composition is authored at. `style.orbDiameter` scales this once.
        static let baseDiameter: CGFloat = 320

        /// The painted sphere covers this fraction of its texture canvas; the remaining
        /// margin is the soft silhouette / rim falloff.
        static let bodyCircleFraction: CGFloat = 0.936
        static let bodySize: CGFloat = baseDiameter / bodyCircleFraction

        static let haloSize: CGFloat = baseDiameter * 2.85
        static let innerGlowSize: CGFloat = baseDiameter * 1.04
        static let highlightSize: CGFloat = baseDiameter * 0.38
        static let highlightOffset = CGPoint(x: -baseDiameter * 0.19, y: baseDiameter * 0.21)
        static let rimSize: CGFloat = bodySize

        static let ringSemiMajors: [CGFloat] = [baseDiameter * 0.63, baseDiameter * 0.78]
        static let ringStyles: [CalmSpaceOrbRingTexture] = [.wide, .flat]
        static let ringTilts: [CGFloat] = [-0.26, 0.16]
        static let ringEllipseFraction: CGFloat = 0.94

        static let particleSizes: [CGFloat] = [3.3, 2.7, 3.9]
        static let particleTracks: [Int] = [0, 1, 0]
        static let particlePhases: [CGFloat] = [0.18, 0.62, 0.81]

        static let starCountDark = 46
        static let starCountLight = 30
        static let maxStars = starCountDark

        static let ambientAnchors: [CGPoint] = [
            CGPoint(x: 0.18, y: 0.80),
            CGPoint(x: 0.84, y: 0.44),
            CGPoint(x: 0.50, y: 0.08)
        ]
        static let ambientSizeFactors: [CGFloat] = [0.95, 1.12, 0.82]
        static let ambientDrifts: [CGPoint] = [
            CGPoint(x: 16, y: -12),
            CGPoint(x: -20, y: 15),
            CGPoint(x: 12, y: 9)
        ]
        static let ambientHalfCycles: [TimeInterval] = [34, 41, 29]
        static let ambientTints: [Int] = [0, 1, 0]
    }

    private enum Motion {
        /// Long custom-action chunk; phase is accumulated by hand so a speed change never
        /// restarts a cycle. `elapsed` only resets once an hour, which the step functions
        /// detect and treat as a fresh delta.
        static let actionChunk: TimeInterval = 3600
        static let breathingScaleAmplitude: CGFloat = 0.010
        static let breathingHarmonicAmplitude: CGFloat = 0.0035
        static let haloAlphaAmplitude: CGFloat = 0.075
        static let haloAlphaHarmonicAmplitude: CGFloat = 0.02
    }

    private enum ActionKey {
        static let breathing = "calmspace.breathing"
        static let flowRotation = "calmspace.flowRotation"
        static let orbit = "calmspace.orbit"
        static let twinkle = "calmspace.twinkle"
        static let drift = "calmspace.drift"
        static let tint = "calmspace.tint"
        static let bodyCrossfade = "calmspace.bodyCrossfade"
        static let flowCrossfade = "calmspace.flowCrossfade"
    }

    private struct OrbitTrack {
        let semiMajor: CGFloat
        let aspect: CGFloat
        let tilt: CGFloat
    }

    /// Per-mode rhythm. Composition is identical; only the internal current differs.
    private struct MotionProfile: Equatable {
        let breathingPeriod: TimeInterval
        let flowPeriod: TimeInterval
        let orbitPeriods: [TimeInterval]

        static func make(for mode: AppMode) -> MotionProfile {
            switch mode {
            case .macCare:
                return MotionProfile(
                    breathingPeriod: 7.4,
                    flowPeriod: 54,
                    orbitPeriods: [48, 54, 58]
                )
            case .workRhythm:
                return MotionProfile(
                    breathingPeriod: 6.6,
                    flowPeriod: 47,
                    orbitPeriods: [42, 46, 51]
                )
            }
        }
    }

    private struct BreathState {
        var phase: CGFloat = 0
        var lastElapsed: CGFloat = 0
    }

    // MARK: - State

    private var lastStyle: CalmSpaceOrbStyle?
    private var bodyKey: CalmSpaceOrbBodyKey?
    private var flowKey: CalmSpaceOrbFlowKey?
    private var isReducedMotion = false
    private var motionProfile: MotionProfile?
    private var haloBaseAlpha: CGFloat = 0
    private var breathState = BreathState()

    private let backgroundLayer = SKNode()
    private let orbRoot = SKNode()
    private let breathNode = SKNode()
    private let flowContainer = SKNode()

    private let haloNode = SKSpriteNode(color: .clear, size: .zero)
    private let bodyNode = SKSpriteNode(color: .clear, size: .zero)
    private let bodyOverlayNode = SKSpriteNode(color: .clear, size: .zero)
    private let flowNode = SKSpriteNode(color: .clear, size: .zero)
    private let flowOverlayNode = SKSpriteNode(color: .clear, size: .zero)
    private let innerGlowNode = SKSpriteNode(color: .clear, size: .zero)
    private let highlightNode = SKSpriteNode(color: .clear, size: .zero)
    private let rimNode = SKSpriteNode(color: .clear, size: .zero)
    private let ringNodes = [
        SKSpriteNode(color: .clear, size: .zero),
        SKSpriteNode(color: .clear, size: .zero)
    ]

    private var orbitTracks: [OrbitTrack] = []
    private var particles: [CalmSpaceOrbParticleNode] = []
    private var starNodes: [CalmSpaceOrbStarNode] = []
    private var ambientGlows: [CalmSpaceOrbAmbientGlow] = []

    // MARK: - Lifecycle

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        buildLayers()
        buildOrb()
        buildBackground()
        layoutBackground()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    // MARK: - SwiftUI inputs

    /// Applies a new style. Diffed internally: equal style input does almost nothing, and
    /// geometry-only changes (live window resize) never restart an animation or touch a
    /// texture, which is what keeps resize free of flashes and jumps.
    func apply(style: CalmSpaceOrbStyle) {
        let previous = lastStyle
        let palette = CalmSpaceOrbPalette.make(style: style)
        let intensity = CalmSpaceOrbIntensity.make(isDark: palette.isDark)
        let isFirst = previous == nil
        let modeChanged = previous.map { $0.mode != style.mode } ?? true
        let themeChanged = isFirst || previous?.isDark != palette.isDark
        let reduceMotionChanged = isFirst || previous?.reduceMotion != style.reduceMotion

        lastStyle = style
        isReducedMotion = style.reduceMotion

        applyGeometry(style: style)

        // Mode switches read as a short crossfade; health / appearance shifts use the
        // slightly longer 0.65 s breathing-out of the status colour.
        let appearanceDuration: TimeInterval = isFirst ? 0 : (modeChanged ? 0.5 : 0.65)
        applyBodyTexture(palette: palette, intensity: intensity, duration: appearanceDuration)
        applyFlowTexture(palette: palette, intensity: intensity, duration: appearanceDuration)
        applyTintedNodes(palette: palette, intensity: intensity, duration: appearanceDuration)

        // Stars and ambience only depend on the colour scheme and on Reduce Motion, so
        // health / mode updates never re-tint or re-phase them.
        if themeChanged || reduceMotionChanged {
            applyStars(palette: palette, intensity: intensity)
            applyAmbientGlowAppearance(palette: palette, intensity: intensity)
        }

        applyMotion(
            profile: MotionProfile.make(for: style.mode),
            haloAlpha: intensity.haloAlpha,
            isFirst: isFirst,
            modeChanged: modeChanged,
            reduceMotionChanged: reduceMotionChanged
        )
    }

    // MARK: - Size / geometry

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutBackground()
        guard size.width > 0, size.height > 0, let lastStyle else { return }
        // Always re-apply the exact style geometry. SwiftUI can send the final style before
        // the NSView has adopted its new frame (or an interim min-size style first); scaling
        // the old center by the size ratio would then double-scale it and push the orb off
        // centre on large windows.
        applyGeometry(style: lastStyle)
    }

    /// Called by the host view after layout. Covers the case where the very first style was
    /// applied while the view was still `.zero` sized and no later `didChangeSize` fires
    /// (the scene's fallback size can happen to equal the final view size).
    func updateViewportLayout() {
        guard size.width > 0, size.height > 0 else { return }
        layoutBackground()
        if let lastStyle {
            applyGeometry(style: lastStyle)
        }
    }

    private func applyGeometry(style: CalmSpaceOrbStyle) {
        guard size.width > 0, size.height > 0 else { return }
        applyOrbTransform(screenCenter: style.orbCenter, diameter: style.orbDiameter)
    }

    private func applyOrbTransform(screenCenter: CGPoint, diameter: CGFloat) {
        // `orbCenter` is SwiftUI top-left window coordinates; the scene is y-up, so the
        // centre is flipped exactly once here.
        orbRoot.position = CGPoint(x: screenCenter.x, y: size.height - screenCenter.y)
        // One uniform scale keeps every child — sphere, rings, particle path — circular.
        orbRoot.setScale(max(diameter, 1) / Metrics.baseDiameter)
    }

    /// Re-projects the normalised starfield and ambience onto the current scene size.
    /// Positions/sizes only; no node is created, removed or restarted.
    private func layoutBackground() {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        for star in starNodes {
            star.position = CGPoint(
                x: star.normalizedPosition.x * width,
                y: star.normalizedPosition.y * height
            )
        }
        let reference = max(width, height)
        for glow in ambientGlows {
            glow.root.position = CGPoint(
                x: glow.anchor.x * width,
                y: glow.anchor.y * height
            )
            let dimension = reference * glow.sizeFactor
            glow.sprite.size = CGSize(width: dimension, height: dimension)
        }
    }

    // MARK: - Scene graph

    private func buildLayers() {
        backgroundLayer.zPosition = -100
        addChild(backgroundLayer)

        orbRoot.zPosition = 0
        addChild(orbRoot)

        // The breathing driver scales the complete orb composition uniformly; children are
        // authored around (0, 0) so this cannot skew anything.
        breathNode.zPosition = 0
        orbRoot.addChild(breathNode)

        haloNode.zPosition = -2
        haloNode.size = CGSize(width: Metrics.haloSize, height: Metrics.haloSize)
        haloNode.texture = CalmSpaceOrbTextures.halo()
        haloNode.alpha = 0
        haloNode.colorBlendFactor = 1
        breathNode.addChild(haloNode)

        bodyNode.zPosition = 0
        bodyNode.size = CGSize(width: Metrics.bodySize, height: Metrics.bodySize)
        breathNode.addChild(bodyNode)

        bodyOverlayNode.zPosition = 0.5
        bodyOverlayNode.size = CGSize(width: Metrics.bodySize, height: Metrics.bodySize)
        bodyOverlayNode.alpha = 0
        breathNode.addChild(bodyOverlayNode)

        flowContainer.zPosition = 1
        flowNode.size = CGSize(width: Metrics.bodySize, height: Metrics.bodySize)
        flowOverlayNode.size = CGSize(width: Metrics.bodySize, height: Metrics.bodySize)
        flowOverlayNode.alpha = 0
        flowContainer.addChild(flowNode)
        flowContainer.addChild(flowOverlayNode)
        breathNode.addChild(flowContainer)

        innerGlowNode.zPosition = 2
        innerGlowNode.size = CGSize(width: Metrics.innerGlowSize, height: Metrics.innerGlowSize)
        innerGlowNode.texture = CalmSpaceOrbTextures.innerGlow()
        innerGlowNode.alpha = 0
        breathNode.addChild(innerGlowNode)

        rimNode.zPosition = 3
        rimNode.size = CGSize(width: Metrics.rimSize, height: Metrics.rimSize)
        rimNode.texture = CalmSpaceOrbTextures.rim()
        rimNode.alpha = 0
        breathNode.addChild(rimNode)

        highlightNode.zPosition = 4
        highlightNode.size = CGSize(width: Metrics.highlightSize, height: Metrics.highlightSize)
        highlightNode.position = Metrics.highlightOffset
        highlightNode.texture = CalmSpaceOrbTextures.highlight()
        highlightNode.alpha = 0
        breathNode.addChild(highlightNode)
    }

    private func buildOrb() {
        for (index, ring) in ringNodes.enumerated() where Metrics.ringSemiMajors.indices.contains(index) {
            let style = Metrics.ringStyles[index]
            let semimajor = Metrics.ringSemiMajors[index]
            // The baked ellipse fills `ringEllipseFraction` of its (square) texture, so the
            // node is sized up by the inverse to get the intended orbit radius in base units.
            let side = (semimajor * 2) / Metrics.ringEllipseFraction
            ring.size = CGSize(width: side, height: side)
            ring.texture = CalmSpaceOrbTextures.orbitRing(style)
            ring.colorBlendFactor = 1
            ring.zPosition = 5
            ring.zRotation = Metrics.ringTilts[index]
            ring.alpha = 0
            breathNode.addChild(ring)
        }

        orbitTracks = Metrics.ringSemiMajors.enumerated().map { index, semimajor in
            OrbitTrack(
                semiMajor: semimajor,
                aspect: Metrics.ringStyles[index].aspect,
                tilt: Metrics.ringTilts[index]
            )
        }

        for index in Metrics.particleSizes.indices {
            let size = Metrics.particleSizes[index]
            let particle = CalmSpaceOrbParticleNode(
                color: .clear,
                size: CGSize(width: size, height: size)
            )
            particle.texture = CalmSpaceOrbTextures.particle()
            particle.colorBlendFactor = 1
            particle.zPosition = 6
            particle.alpha = 0
            particle.trackIndex = Metrics.particleTracks[index]
            particle.phaseOffset = Metrics.particlePhases[index]
            particle.angle = Metrics.particlePhases[index] * 2 * CGFloat.pi
            breathNode.addChild(particle)
            particles.append(particle)
        }
    }

    private func buildBackground() {
        var random = CalmSpaceOrbRandom(seed: 0x4A6F657950657441)

        for index in 0..<Metrics.maxStars {
            let star = CalmSpaceOrbStarNode(color: .clear, size: .zero)
            star.texture = index % 3 == 0
                ? CalmSpaceOrbTextures.softStar()
                : CalmSpaceOrbTextures.tinyStar()
            star.colorBlendFactor = 1
            let dimension = random.value(in: 1.0...2.6)
            star.size = CGSize(width: dimension, height: dimension)
            star.normalizedPosition = CGPoint(x: random.unit(), y: random.unit())
            star.alphaRank = random.unit()
            star.twinklePeriod = TimeInterval(random.value(in: 6...18))
            star.twinkleDepth = random.value(in: 0.28...0.5)
            star.zPosition = 0
            star.isHidden = true
            backgroundLayer.addChild(star)
            starNodes.append(star)
        }

        for index in Metrics.ambientAnchors.indices {
            let root = SKNode()
            root.zPosition = CGFloat(index) - CGFloat(Metrics.ambientAnchors.count)
            backgroundLayer.addChild(root)

            // The sprite is a child of the anchor node so the slow drift action can move
            // it while resizes keep repositioning only the (stable) parent.
            let sprite = SKSpriteNode(color: .clear, size: .zero)
            sprite.texture = CalmSpaceOrbTextures.ambientGlow()
            sprite.colorBlendFactor = 1
            sprite.alpha = 0
            root.addChild(sprite)

            ambientGlows.append(
                CalmSpaceOrbAmbientGlow(
                    root: root,
                    sprite: sprite,
                    anchor: Metrics.ambientAnchors[index],
                    sizeFactor: Metrics.ambientSizeFactors[index],
                    drift: Metrics.ambientDrifts[index],
                    halfCycle: Metrics.ambientHalfCycles[index],
                    tintIndex: Metrics.ambientTints[index]
                )
            )
        }
    }

    // MARK: - Appearance

    private func applyBodyTexture(
        palette: CalmSpaceOrbPalette,
        intensity: CalmSpaceOrbIntensity,
        duration: TimeInterval
    ) {
        bodyNode.alpha = intensity.bodyAlpha
        let key = CalmSpaceOrbBodyKey(
            isDark: palette.isDark,
            health: palette.health,
            mode: palette.mode
        )
        guard bodyKey != key || bodyNode.texture == nil else { return }
        guard let texture = CalmSpaceOrbTextures.bodyTexture(palette: palette) else { return }
        bodyKey = key

        guard bodyNode.texture != nil, duration > 0 else {
            commitBodyTexture(texture)
            return
        }
        // Fold any in-flight crossfade into the body first so rapid health changes cannot
        // stack blend layers and end on the wrong texture.
        if bodyOverlayNode.texture != nil {
            commitBodyTexture(bodyOverlayNode.texture)
        }
        bodyOverlayNode.removeAction(forKey: ActionKey.bodyCrossfade)
        bodyOverlayNode.texture = texture
        bodyOverlayNode.alpha = 0
        bodyOverlayNode.run(
            SKAction.sequence([
                SKAction.fadeAlpha(to: intensity.bodyAlpha, duration: duration),
                SKAction.run { [weak self] in self?.commitBodyTexture(texture) }
            ]),
            withKey: ActionKey.bodyCrossfade
        )
    }

    private func commitBodyTexture(_ texture: SKTexture?) {
        bodyNode.texture = texture
        bodyOverlayNode.texture = nil
        bodyOverlayNode.alpha = 0
    }

    private func applyFlowTexture(
        palette: CalmSpaceOrbPalette,
        intensity: CalmSpaceOrbIntensity,
        duration: TimeInterval
    ) {
        flowNode.alpha = intensity.flowAlpha
        let key = CalmSpaceOrbFlowKey(isDark: palette.isDark, mode: palette.mode)
        guard flowKey != key || flowNode.texture == nil else { return }
        guard let texture = CalmSpaceOrbTextures.flowTexture(
            isDark: palette.isDark,
            mode: palette.mode
        ) else { return }
        flowKey = key

        guard flowNode.texture != nil, duration > 0 else {
            commitFlowTexture(texture)
            return
        }
        if flowOverlayNode.texture != nil {
            commitFlowTexture(flowOverlayNode.texture)
        }
        flowOverlayNode.removeAction(forKey: ActionKey.flowCrossfade)
        flowOverlayNode.texture = texture
        flowOverlayNode.alpha = 0
        flowOverlayNode.color = palette.inner
        flowOverlayNode.colorBlendFactor = 1
        flowOverlayNode.run(
            SKAction.sequence([
                SKAction.fadeAlpha(to: intensity.flowAlpha, duration: duration),
                SKAction.run { [weak self] in self?.commitFlowTexture(texture) }
            ]),
            withKey: ActionKey.flowCrossfade
        )
    }

    private func commitFlowTexture(_ texture: SKTexture?) {
        flowNode.texture = texture
        flowOverlayNode.texture = nil
        flowOverlayNode.alpha = 0
    }

    private func applyTintedNodes(
        palette: CalmSpaceOrbPalette,
        intensity: CalmSpaceOrbIntensity,
        duration: TimeInterval
    ) {
        bodyNode.alpha = intensity.bodyAlpha
        flowNode.alpha = intensity.flowAlpha

        tint(haloNode, color: palette.glow, duration: duration)
        tint(innerGlowNode, color: palette.inner, duration: duration)
        tint(highlightNode, color: palette.highlight, duration: duration)
        tint(rimNode, color: palette.edge, duration: duration)
        tint(flowNode, color: palette.inner, duration: duration)
        for ring in ringNodes {
            tint(ring, color: palette.orbitLine, duration: duration)
        }
        for particle in particles {
            tint(particle, color: palette.particle, duration: duration)
        }

        innerGlowNode.alpha = intensity.innerGlowAlpha
        highlightNode.alpha = intensity.highlightAlpha
        rimNode.alpha = intensity.rimAlpha
        for (index, ring) in ringNodes.enumerated() {
            ring.alpha = intensity.ringAlpha[min(index, intensity.ringAlpha.count - 1)]
        }
        for particle in particles {
            particle.alpha = intensity.particleAlpha
        }
    }

    /// White-alpha textures are tinted at runtime, so a status/theme change is a colour
    /// animation instead of a texture bake. `SKAction.colorize` starts from the current
    /// colour, which keeps repeated updates idempotent.
    private func tint(_ node: SKSpriteNode, color: NSColor, duration: TimeInterval) {
        node.colorBlendFactor = 1
        guard duration > 0 else {
            node.color = color
            return
        }
        guard !node.color.isEqual(color) else { return }
        node.run(
            SKAction.colorize(with: color, colorBlendFactor: 1, duration: duration),
            withKey: ActionKey.tint
        )
    }

    private func applyStars(palette: CalmSpaceOrbPalette, intensity: CalmSpaceOrbIntensity) {
        let visibleCount = palette.isDark ? Metrics.starCountDark : Metrics.starCountLight
        let range = intensity.starAlphaRange
        for (index, star) in starNodes.enumerated() {
            // Light theme keeps a sparser, mistier field: fewer stars, lower alpha.
            let isVisible = index < visibleCount
            star.isHidden = !isVisible
            star.removeAction(forKey: ActionKey.twinkle)
            guard isVisible else { continue }

            star.color = palette.star
            star.colorBlendFactor = 1
            star.baseAlpha = range.lowerBound + (range.upperBound - range.lowerBound) * star.alphaRank
            if isReducedMotion {
                star.alpha = star.baseAlpha
            } else {
                installStarTwinkle(star)
            }
        }
    }

    private func installStarTwinkle(_ star: CalmSpaceOrbStarNode) {
        star.alpha = star.baseAlpha
        let low = star.baseAlpha * (1 - star.twinkleDepth)
        let high = star.baseAlpha * (1 + star.twinkleDepth * 0.55)
        let half = max(star.twinklePeriod / 2, 1)
        let fadeDown = SKAction.fadeAlpha(to: low, duration: half)
        fadeDown.timingMode = .easeInEaseOut
        let fadeUp = SKAction.fadeAlpha(to: high, duration: half)
        fadeUp.timingMode = .easeInEaseOut
        star.run(
            SKAction.repeatForever(SKAction.sequence([fadeDown, fadeUp])),
            withKey: ActionKey.twinkle
        )
    }

    private func applyAmbientGlowAppearance(
        palette: CalmSpaceOrbPalette,
        intensity: CalmSpaceOrbIntensity
    ) {
        for (index, glow) in ambientGlows.enumerated() {
            glow.sprite.color = glow.tintIndex == 1
                ? palette.ambientSecondary
                : palette.ambientPrimary
            glow.sprite.colorBlendFactor = 1
            glow.sprite.alpha = intensity.ambientAlpha[min(index, intensity.ambientAlpha.count - 1)]
        }
    }

    // MARK: - Motion

    private func applyMotion(
        profile: MotionProfile,
        haloAlpha: CGFloat,
        isFirst: Bool,
        modeChanged: Bool,
        reduceMotionChanged: Bool
    ) {
        motionProfile = profile
        haloBaseAlpha = haloAlpha

        if isFirst || reduceMotionChanged {
            installBreathing()
            installAmbientDrift()
            installOrbitActions()
        }
        if isFirst || modeChanged || reduceMotionChanged {
            installFlowRotation(duration: profile.flowPeriod)
        }
        if isFirst || modeChanged {
            applyOrbitPeriods(profile: profile)
        }
        if isReducedMotion {
            breathNode.setScale(1)
            haloNode.alpha = haloAlpha
        }
    }

    private func installBreathing() {
        breathNode.removeAction(forKey: ActionKey.breathing)
        breathState = BreathState()
        breathNode.setScale(1)
        haloNode.alpha = haloBaseAlpha
        guard !isReducedMotion else { return }

        let action = SKAction.repeatForever(
            SKAction.customAction(withDuration: Motion.actionChunk) { [weak self] _, elapsed in
                self?.stepBreathing(elapsed: elapsed)
            }
        )
        breathNode.run(action, withKey: ActionKey.breathing)
    }

    /// Breathing is phase-accumulated rather than a repeating scale/fade sequence: the
    /// period can change (mode switch, re-enable motion) without a jump, and the second,
    /// slower harmonic keeps it from ever feeling like a mechanical pulse.
    private func stepBreathing(elapsed: CGFloat) {
        guard let profile = motionProfile else { return }
        let delta = elapsed >= breathState.lastElapsed ? elapsed - breathState.lastElapsed : elapsed
        breathState.lastElapsed = elapsed
        guard delta > 0 else { return }

        breathState.phase += delta * (2 * CGFloat.pi / CGFloat(max(profile.breathingPeriod, 1)))
        if breathState.phase > 2 * CGFloat.pi {
            breathState.phase -= 2 * CGFloat.pi
        }

        let primary = sin(breathState.phase)
        let harmonic = sin(breathState.phase * 0.5 + 0.9)
        breathNode.setScale(
            1
                + Motion.breathingScaleAmplitude * primary
                + Motion.breathingHarmonicAmplitude * harmonic
        )
        haloNode.alpha = haloBaseAlpha * (
            0.94
                + Motion.haloAlphaAmplitude * primary
                + Motion.haloAlphaHarmonicAmplitude * harmonic
        )
    }

    private func installFlowRotation(duration: TimeInterval) {
        // `rotate(byAngle:)` is relative, so swapping the action for a new duration keeps
        // the current flow angle — no visible jump on a mode switch.
        flowContainer.removeAction(forKey: ActionKey.flowRotation)
        guard !isReducedMotion else { return }
        let rotate = SKAction.rotate(byAngle: 2 * CGFloat.pi, duration: max(duration, 1))
        flowContainer.run(SKAction.repeatForever(rotate), withKey: ActionKey.flowRotation)
    }

    private func applyOrbitPeriods(profile: MotionProfile) {
        guard !profile.orbitPeriods.isEmpty else { return }
        for (index, particle) in particles.enumerated() {
            particle.period = profile.orbitPeriods[min(index, profile.orbitPeriods.count - 1)]
        }
    }

    private func installOrbitActions() {
        for particle in particles {
            particle.removeAction(forKey: ActionKey.orbit)
            particle.lastElapsed = 0
            guard !isReducedMotion else {
                particle.position = orbitPoint(trackIndex: particle.trackIndex, angle: particle.angle)
                continue
            }
            let action = SKAction.repeatForever(
                SKAction.customAction(withDuration: Motion.actionChunk) { [weak self, weak particle] _, elapsed in
                    guard let self, let particle else { return }
                    self.stepParticle(particle, elapsed: elapsed)
                }
            )
            particle.run(action, withKey: ActionKey.orbit)
        }
    }

    private func stepParticle(_ particle: CalmSpaceOrbParticleNode, elapsed: CGFloat) {
        let delta = elapsed >= particle.lastElapsed ? elapsed - particle.lastElapsed : elapsed
        particle.lastElapsed = elapsed
        guard delta > 0 else { return }

        particle.angle += delta * (2 * CGFloat.pi / CGFloat(max(particle.period, 1)))
        particle.angle = particle.angle.truncatingRemainder(dividingBy: 2 * CGFloat.pi)
        // Positions are computed on the ellipse and rotation applied by hand; the particle
        // node itself is never non-uniformly scaled, so it stays a round dot.
        particle.position = orbitPoint(trackIndex: particle.trackIndex, angle: particle.angle)
    }

    private func orbitPoint(trackIndex: Int, angle: CGFloat) -> CGPoint {
        guard orbitTracks.indices.contains(trackIndex) else { return .zero }
        let track = orbitTracks[trackIndex]
        let x = track.semiMajor * cos(angle)
        let y = track.semiMajor * track.aspect * sin(angle)
        let cosTilt = cos(track.tilt)
        let sinTilt = sin(track.tilt)
        return CGPoint(
            x: x * cosTilt - y * sinTilt,
            y: x * sinTilt + y * cosTilt
        )
    }

    private func installAmbientDrift() {
        for glow in ambientGlows {
            glow.sprite.removeAction(forKey: ActionKey.drift)
            glow.sprite.position = .zero
            guard !isReducedMotion else { continue }
            let move = SKAction.moveBy(
                x: glow.drift.x,
                y: glow.drift.y,
                duration: glow.halfCycle
            )
            move.timingMode = .easeInEaseOut
            // One out-and-back cycle: 58 s / 68 s / 82 s. Imperceptible unless watched.
            let action = SKAction.repeatForever(SKAction.sequence([move, move.reversed()]))
            glow.sprite.run(action, withKey: ActionKey.drift)
        }
    }
}

// MARK: - Node types

/// One background star. The layout is normalised (0…1) so window resizes only reproject
/// positions instead of rebuilding the field.
private final class CalmSpaceOrbStarNode: SKSpriteNode {
    var normalizedPosition = CGPoint.zero
    var alphaRank: CGFloat = 0
    var baseAlpha: CGFloat = 0
    var twinklePeriod: TimeInterval = 10
    var twinkleDepth: CGFloat = 0.35
}

/// One tiny body travelling along an orbit ring. It is a plain round sprite; only its
/// position is animated.
private final class CalmSpaceOrbParticleNode: SKSpriteNode {
    var trackIndex = 0
    var phaseOffset: CGFloat = 0
    var period: TimeInterval = 50
    var angle: CGFloat = 0
    var lastElapsed: CGFloat = 0
}

private struct CalmSpaceOrbAmbientGlow {
    let root: SKNode
    let sprite: SKSpriteNode
    let anchor: CGPoint
    let sizeFactor: CGFloat
    let drift: CGPoint
    let halfCycle: TimeInterval
    let tintIndex: Int
}

// MARK: - Per-theme intensities

/// Theme-specific alphas. The palette already carries health/mode hue blending; these
/// values only describe how present each layer is in dark vs light.
private struct CalmSpaceOrbIntensity {
    let bodyAlpha: CGFloat
    let haloAlpha: CGFloat
    let innerGlowAlpha: CGFloat
    let highlightAlpha: CGFloat
    let rimAlpha: CGFloat
    let ringAlpha: [CGFloat]
    let particleAlpha: CGFloat
    let flowAlpha: CGFloat
    let starAlphaRange: ClosedRange<CGFloat>
    let ambientAlpha: [CGFloat]

    static func make(isDark: Bool) -> CalmSpaceOrbIntensity {
        isDark ? .dark : .light
    }

    static let dark = CalmSpaceOrbIntensity(
        bodyAlpha: 1.0,
        haloAlpha: 0.46,
        innerGlowAlpha: 0.13,
        highlightAlpha: 0.32,
        rimAlpha: 0.40,
        ringAlpha: [0.32, 0.21],
        particleAlpha: 0.72,
        flowAlpha: 0.40,
        starAlphaRange: 0.05...0.16,
        ambientAlpha: [0.20, 0.16, 0.12]
    )

    static let light = CalmSpaceOrbIntensity(
        bodyAlpha: 0.95,
        haloAlpha: 0.32,
        innerGlowAlpha: 0.18,
        highlightAlpha: 0.42,
        rimAlpha: 0.34,
        ringAlpha: [0.26, 0.18],
        particleAlpha: 0.62,
        flowAlpha: 0.30,
        starAlphaRange: 0.04...0.10,
        ambientAlpha: [0.22, 0.18, 0.14]
    )
}

// MARK: - Texture keys

private struct CalmSpaceOrbBodyKey: Hashable {
    let isDark: Bool
    let health: CalmSpaceHealthLevel
    let mode: AppMode
}

private struct CalmSpaceOrbFlowKey: Hashable {
    let isDark: Bool
    let mode: AppMode
}

private enum CalmSpaceOrbRingTexture: Hashable {
    case wide
    case flat

    /// Minor/major ratio of the baked ellipse.
    var aspect: CGFloat {
        switch self {
        case .wide: return 0.30
        case .flat: return 0.235
        }
    }
}

// MARK: - Texture cache

/// All art is generated once with Core Graphics and cached as `SKTexture`s.
///
/// The sphere body is the only multicolour texture (gradient core → rim), so it is keyed
/// by theme + health + mode and kept small (LRU-capped). Every other layer is a
/// white-alpha mask that is tinted from `CalmSpaceOrbPalette` at runtime, which means
/// status transitions are colour animations, not texture bakes. Generation never depends
/// on the window size, so a live resize can never re-bake a texture.
private enum CalmSpaceOrbTextures {
    private static let orbCanvas = 512
    private static let glowCanvas = 256
    private static let starCanvas = 64
    private static let smallCanvas = 32
    private static let bodyCacheLimit = 6

    private static let bodyCircleFraction: CGFloat = 0.936
    private static let ringEllipseFraction: CGFloat = 0.94

    private static var whiteCache: [CalmSpaceOrbWhiteTexture: SKTexture] = [:]
    private static var bodyCache: [CalmSpaceOrbBodyKey: SKTexture] = [:]
    private static var bodyCacheOrder: [CalmSpaceOrbBodyKey] = []
    private static var flowCache: [CalmSpaceOrbFlowKey: SKTexture] = [:]
    private static var ringCache: [CalmSpaceOrbRingTexture: SKTexture] = [:]

    // MARK: Public accessors

    static func bodyTexture(palette: CalmSpaceOrbPalette) -> SKTexture? {
        let key = CalmSpaceOrbBodyKey(
            isDark: palette.isDark,
            health: palette.health,
            mode: palette.mode
        )
        if let cached = bodyCache[key] { return cached }
        guard let texture = makeBodyTexture(palette: palette) else { return nil }
        bodyCache[key] = texture
        bodyCacheOrder.append(key)
        if bodyCacheOrder.count > bodyCacheLimit {
            let evicted = bodyCacheOrder.removeFirst()
            bodyCache[evicted] = nil
        }
        return texture
    }

    static func flowTexture(isDark: Bool, mode: AppMode) -> SKTexture? {
        let key = CalmSpaceOrbFlowKey(isDark: isDark, mode: mode)
        if let cached = flowCache[key] { return cached }
        guard let texture = makeFlowTexture(isDark: isDark, mode: mode) else { return nil }
        flowCache[key] = texture
        return texture
    }

    static func halo() -> SKTexture? {
        cachedWhite(.halo) {
            let canvas = orbCanvas
            return makeRadialTexture(
                canvas: canvas,
                stops: [
                    (0.00, white(1.00)),
                    (0.14, white(0.72)),
                    (0.32, white(0.38)),
                    (0.52, white(0.16)),
                    (0.74, white(0.045)),
                    (1.00, white(0.0))
                ]
            )
        }
    }

    static func innerGlow() -> SKTexture? {
        cachedWhite(.innerGlow) {
            makeRadialTexture(
                canvas: glowCanvas,
                stops: [
                    (0.00, white(0.85)),
                    (0.22, white(0.50)),
                    (0.50, white(0.20)),
                    (0.78, white(0.05)),
                    (1.00, white(0.0))
                ]
            )
        }
    }

    static func highlight() -> SKTexture? {
        cachedWhite(.highlight) {
            let canvas = glowCanvas
            let side = CGFloat(canvas)
            guard let context = makeBitmapContext(canvas: canvas) else { return nil }
            // Baked ellipse + tilt: the sprite itself stays uniformly scaled.
            context.saveGState()
            context.translateBy(x: side / 2, y: side / 2)
            context.rotate(by: -0.62)
            context.scaleBy(x: 1.0, y: 0.66)
            drawRadial(
                context,
                center: .zero,
                radius: side * 0.40,
                stops: [
                    (0.00, white(0.95)),
                    (0.30, white(0.55)),
                    (0.62, white(0.16)),
                    (1.00, white(0.0))
                ]
            )
            context.restoreGState()
            return finish(context)
        }
    }

    static func rim() -> SKTexture? {
        cachedWhite(.rim) {
            let canvas = orbCanvas
            let side = CGFloat(canvas)
            let center = CGPoint(x: side / 2, y: side / 2)
            guard let context = makeBitmapContext(canvas: canvas) else { return nil }
            // Peak at 0.936 of the canvas radius so the light sits exactly on the sphere
            // silhouette painted by `makeBodyTexture`.
            drawRadial(
                context,
                center: center,
                radius: side / 2,
                stops: [
                    (0.00, white(0.0)),
                    (0.90, white(0.0)),
                    (0.928, white(0.20)),
                    (0.936, white(0.85)),
                    (0.946, white(0.34)),
                    (0.960, white(0.06)),
                    (1.00, white(0.0))
                ]
            )
            // Light from the upper-left, agreeing with the specular highlight.
            context.setBlendMode(.destinationIn)
            drawLinear(
                context,
                start: CGPoint(x: 0, y: side),
                end: CGPoint(x: side, y: 0),
                stops: [
                    (0.00, white(1.0)),
                    (0.45, white(0.62)),
                    (1.00, white(0.22))
                ]
            )
            return finish(context)
        }
    }

    static func softStar() -> SKTexture? {
        cachedWhite(.softStar) {
            makeRadialTexture(
                canvas: starCanvas,
                stops: [
                    (0.00, white(1.0)),
                    (0.22, white(0.55)),
                    (0.50, white(0.16)),
                    (0.80, white(0.03)),
                    (1.00, white(0.0))
                ]
            )
        }
    }

    static func tinyStar() -> SKTexture? {
        cachedWhite(.tinyStar) {
            makeRadialTexture(
                canvas: smallCanvas,
                stops: [
                    (0.00, white(0.90)),
                    (0.40, white(0.30)),
                    (0.75, white(0.02)),
                    (1.00, white(0.0))
                ]
            )
        }
    }

    static func particle() -> SKTexture? {
        cachedWhite(.particle) {
            makeRadialTexture(
                canvas: smallCanvas,
                stops: [
                    (0.00, white(1.0)),
                    (0.38, white(0.60)),
                    (0.70, white(0.14)),
                    (1.00, white(0.0))
                ]
            )
        }
    }

    static func ambientGlow() -> SKTexture? {
        cachedWhite(.ambientGlow) {
            makeRadialTexture(
                canvas: glowCanvas,
                stops: [
                    (0.00, white(1.0)),
                    (0.18, white(0.62)),
                    (0.38, white(0.30)),
                    (0.60, white(0.12)),
                    (0.82, white(0.03)),
                    (1.00, white(0.0))
                ]
            )
        }
    }

    static func orbitRing(_ style: CalmSpaceOrbRingTexture) -> SKTexture? {
        if let cached = ringCache[style] { return cached }
        guard let texture = makeOrbitRingTexture(aspect: style.aspect) else { return nil }
        ringCache[style] = texture
        return texture
    }

    // MARK: Sphere / flow bakes

    private static func makeBodyTexture(palette: CalmSpaceOrbPalette) -> SKTexture? {
        let canvas = orbCanvas
        let side = CGFloat(canvas)
        let center = CGPoint(x: side / 2, y: side / 2)
        let radius = side * bodyCircleFraction / 2
        let circle = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        guard let context = makeBitmapContext(canvas: canvas) else { return nil }

        context.saveGState()
        context.addEllipse(in: circle)
        context.clip()

        // Lit from the upper-left: the gradient's focal point is offset, so the sphere
        // reads as a lit volume instead of a flat disc.
        drawRadial(
            context,
            center: center,
            radius: radius * 1.02,
            stops: [
                (0.00, color(palette.inner)),
                (0.18, color(palette.core)),
                (0.46, color(palette.mid)),
                (0.62, color(palette.mid)),
                (0.88, color(palette.deep)),
                (1.00, color(palette.deep))
            ],
            startCenter: CGPoint(x: center.x - radius * 0.16, y: center.y + radius * 0.20)
        )

        // Restrained lower-right occlusion gives the rim volume without dirtying it.
        drawLinear(
            context,
            start: CGPoint(x: side * 0.92, y: side * 0.08),
            end: center,
            stops: [
                (0.00, color(palette.deep, alpha: 0.32)),
                (0.55, color(palette.deep, alpha: 0.07)),
                (1.00, color(palette.deep, alpha: 0.0))
            ]
        )
        context.restoreGState()

        // Soft silhouette: fade the outermost few percent so the rim light, not a hard
        // clip path, defines the edge.
        context.saveGState()
        context.addEllipse(in: circle)
        context.clip()
        context.setBlendMode(.destinationIn)
        drawRadial(
            context,
            center: center,
            radius: radius,
            stops: [
                (0.00, white(1.0)),
                (0.90, white(1.0)),
                (0.965, white(0.82)),
                (1.00, white(0.0))
            ]
        )
        context.restoreGState()

        return finish(context)
    }

    private static func makeFlowTexture(isDark: Bool, mode: AppMode) -> SKTexture? {
        let canvas = orbCanvas
        let side = CGFloat(canvas)
        let center = CGPoint(x: side / 2, y: side / 2)
        let radius = side * bodyCircleFraction / 2
        let circle = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        guard let context = makeBitmapContext(canvas: canvas) else { return nil }

        var seed: UInt64 = 0x2D35_8DCC_AA6C_78A5
        if !isDark { seed ^= 0x9FB2_1C65_1E98_DF25 }
        if mode == .workRhythm { seed ^= 0x51ED_270B_9A3C_4D21 }
        var random = CalmSpaceOrbRandom(seed: seed)

        context.saveGState()
        context.addEllipse(in: circle)
        context.clip()

        // Curved current bands: thick, soft arcs at different radii. Rotating this layer
        // slowly reads as internal flow rather than a static blur.
        for _ in 0..<12 {
            let arcRadius = radius * random.value(in: 0.18...0.90)
            let lineWidth = radius * random.value(in: 0.06...0.14)
            let startAngle = random.value(in: 0...(2 * CGFloat.pi))
            let sweep = random.value(in: 0.9...2.6)
            context.saveGState()
            context.setShadow(offset: .zero, blur: lineWidth * 0.9, color: white(0.55))
            context.setStrokeColor(white(random.value(in: 0.10...0.22)))
            context.setLineWidth(lineWidth)
            let path = CGMutablePath()
            path.addArc(
                center: center,
                radius: arcRadius,
                startAngle: startAngle,
                endAngle: startAngle + sweep,
                clockwise: false
            )
            context.addPath(path)
            context.strokePath()
            context.restoreGState()
        }

        // Thin filaments for finer internal structure.
        context.saveGState()
        context.setShadow(offset: .zero, blur: radius * 0.05, color: white(0.40))
        context.setStrokeColor(white(0.18))
        context.setLineWidth(radius * 0.02)
        for _ in 0..<5 {
            let arcRadius = radius * random.value(in: 0.30...0.95)
            let startAngle = random.value(in: 0...(2 * CGFloat.pi))
            let sweep = random.value(in: 1.0...2.8)
            let path = CGMutablePath()
            path.addArc(
                center: center,
                radius: arcRadius,
                startAngle: startAngle,
                endAngle: startAngle + sweep,
                clockwise: false
            )
            context.addPath(path)
            context.strokePath()
        }
        context.restoreGState()

        // Carve a few narrow channels so the bands separate into distinct currents instead
        // of merging into a uniform haze.
        context.setBlendMode(.destinationOut)
        for _ in 0..<3 {
            let arcRadius = radius * random.value(in: 0.20...0.90)
            let lineWidth = radius * random.value(in: 0.03...0.06)
            let startAngle = random.value(in: 0...(2 * CGFloat.pi))
            let sweep = random.value(in: 1.2...2.8)
            context.saveGState()
            context.setShadow(offset: .zero, blur: lineWidth * 0.8, color: white(0.90))
            context.setStrokeColor(white(random.value(in: 0.45...0.65)))
            context.setLineWidth(lineWidth)
            let path = CGMutablePath()
            path.addArc(
                center: center,
                radius: arcRadius,
                startAngle: startAngle,
                endAngle: startAngle + sweep,
                clockwise: false
            )
            context.addPath(path)
            context.strokePath()
            context.restoreGState()
        }
        context.setBlendMode(.normal)
        context.restoreGState()

        // Feather near the rim so flow never touches the silhouette.
        context.saveGState()
        context.addEllipse(in: circle)
        context.clip()
        context.setBlendMode(.destinationIn)
        drawRadial(
            context,
            center: center,
            radius: radius,
            stops: [
                (0.00, white(0.55)),
                (0.30, white(0.85)),
                (0.62, white(1.00)),
                (0.86, white(0.55)),
                (1.00, white(0.0))
            ]
        )
        context.restoreGState()

        return finish(context)
    }

    private static func makeOrbitRingTexture(aspect: CGFloat) -> SKTexture? {
        let canvas = orbCanvas
        let side = CGFloat(canvas)
        let width = side * ringEllipseFraction
        let height = width * aspect
        let rect = CGRect(
            x: (side - width) / 2,
            y: (side - height) / 2,
            width: width,
            height: height
        )
        guard let context = makeBitmapContext(canvas: canvas) else { return nil }

        // Very soft bloom first, then a thin core line: this keeps the ring "extremely
        // thin" while avoiding a hard, neon-looking edge.
        context.saveGState()
        context.setShadow(offset: .zero, blur: 8, color: white(0.30))
        context.setStrokeColor(white(0.14))
        context.setLineWidth(3.0)
        context.strokeEllipse(in: rect)
        context.restoreGState()

        context.saveGState()
        context.setShadow(offset: .zero, blur: 2.4, color: white(0.55))
        context.setStrokeColor(white(0.55))
        context.setLineWidth(1.7)
        context.strokeEllipse(in: rect)
        context.restoreGState()

        return finish(context)
    }

    // MARK: White masks

    private enum CalmSpaceOrbWhiteTexture: Hashable {
        case halo
        case innerGlow
        case highlight
        case rim
        case softStar
        case tinyStar
        case particle
        case ambientGlow
    }

    private static func cachedWhite(
        _ kind: CalmSpaceOrbWhiteTexture,
        make: () -> SKTexture?
    ) -> SKTexture? {
        if let cached = whiteCache[kind] { return cached }
        guard let texture = make() else { return nil }
        whiteCache[kind] = texture
        return texture
    }

    private static func makeRadialTexture(
        canvas: Int,
        stops: [(CGFloat, CGColor)]
    ) -> SKTexture? {
        guard let context = makeBitmapContext(canvas: canvas) else { return nil }
        let side = CGFloat(canvas)
        drawRadial(
            context,
            center: CGPoint(x: side / 2, y: side / 2),
            radius: side / 2,
            stops: stops
        )
        return finish(context)
    }

    // MARK: Drawing helpers

    private static func makeBitmapContext(canvas: Int) -> CGContext? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGContext(
            data: nil,
            width: canvas,
            height: canvas,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    private static func finish(_ context: CGContext) -> SKTexture? {
        guard let image = context.makeImage() else { return nil }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        return texture
    }

    private static func white(_ alpha: CGFloat) -> CGColor {
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha)
    }

    private static func color(_ color: NSColor, alpha: CGFloat = 1) -> CGColor {
        let base = color.usingColorSpace(.sRGB)?.cgColor ?? NSColor.white.cgColor
        return base.copy(alpha: alpha) ?? base
    }

    private static func drawRadial(
        _ context: CGContext,
        center: CGPoint,
        radius: CGFloat,
        stops: [(CGFloat, CGColor)],
        startCenter: CGPoint? = nil
    ) {
        guard radius > 0, let gradient = gradient(stops) else { return }
        context.drawRadialGradient(
            gradient,
            startCenter: startCenter ?? center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: []
        )
    }

    private static func drawLinear(
        _ context: CGContext,
        start: CGPoint,
        end: CGPoint,
        stops: [(CGFloat, CGColor)]
    ) {
        guard let gradient = gradient(stops) else { return }
        context.drawLinearGradient(gradient, start: start, end: end, options: [])
    }

    private static func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB), stops.count >= 2 else {
            return nil
        }
        let colors = stops.map { $0.1 } as CFArray
        let locations = stops.map { $0.0 }
        return locations.withUnsafeBufferPointer { buffer in
            CGGradient(colorsSpace: colorSpace, colors: colors, locations: buffer.baseAddress)
        }
    }
}

// MARK: - Deterministic randomness

/// Small SplitMix64 helper. Star positions, sizes and twinkle periods must be stable
/// across window resizes and app launches, so `random()` from the standard library (which
/// is also not available without seeding) is intentionally not used.
private struct CalmSpaceOrbRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    private mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    /// Uniform value in 0..<1.
    mutating func unit() -> CGFloat {
        CGFloat(next() >> 11) / 9_007_199_254_740_992
    }

    mutating func value(in range: ClosedRange<CGFloat>) -> CGFloat {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }
}
