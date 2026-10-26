import SpriteKit

/// Work Rhythm's central visual: an abstract time dial.
///
/// Design: a flat, front-facing instrument — a hairline outer ring with 60 ticks (every
/// 5th tick longer), two fainter concentric circles for depth, a very soft radial halo
/// behind the dial, one slow luminous sweep ("time is flowing"), a fainter and faster
/// hairline arc for liveliness, and a quiet centre dot with a slow breathing glow.
/// Nothing reads as a real clock or a countdown: no numerals, no hands at real clock
/// positions, and no session progress anywhere (Work Rhythm has no timer yet).
///
/// Rules kept in line with the Mac Care orb scene:
/// - motion is exclusively `SKAction`-based (rotate / scale / fade) — no per-frame math,
///   no timer, no DisplayLink of our own,
/// - every texture is a white-alpha Core Graphics mask baked once per process and cached;
///   theme/phase changes are colour + action diffs, never texture bakes, and a window
///   resize only moves the root transform,
/// - the composition is authored in fixed base units and scaled by one root node, so the
///   dial stays circular at every window size.
@MainActor
final class CalmSpaceRhythmScene: SKScene {
    private enum Metrics {
        /// Fixed base composition; `dialRoot` scales this to the reserved central slot.
        static let baseDiameter: CGFloat = 300
        static let sweepHeadRadius: CGFloat = 120
        static let sweepHeadSize: CGFloat = 26
        static let centreGlowSize: CGFloat = 60
        static let centreDotSize: CGFloat = 14

        /// Static Reduce Motion composition: an intentional "paused instrument" pose.
        static let reducedSweepAngle: CGFloat = -0.75
        static let reducedFastArcAngle: CGFloat = 2.1
    }

    /// Phase-driven tuning. `.idle` is the only phase the UI may select in V1; `.focus`
    /// (steadier, more present sweep) and `.rest` (slower, softer) are documented but
    /// inert until a real session state exists. No phase implies a countdown.
    private struct RhythmMotion {
        let sweepPeriod: TimeInterval
        let fastArcPeriod: TimeInterval
        let breathePeriod: TimeInterval
        let sweepPresence: CGFloat
        let fastArcPresence: CGFloat

        static func make(for phase: CalmSpaceRhythmPhase) -> RhythmMotion {
            switch phase {
            case .idle:
                return RhythmMotion(
                    sweepPeriod: 120,
                    fastArcPeriod: 38,
                    breathePeriod: 10,
                    sweepPresence: 1.0,
                    fastArcPresence: 1.0
                )
            case .focus:
                return RhythmMotion(
                    sweepPeriod: 92,
                    fastArcPeriod: 30,
                    breathePeriod: 8,
                    sweepPresence: 1.0,
                    fastArcPresence: 1.15
                )
            case .rest:
                return RhythmMotion(
                    sweepPeriod: 150,
                    fastArcPeriod: 44,
                    breathePeriod: 12,
                    sweepPresence: 0.75,
                    fastArcPresence: 0.5
                )
            }
        }
    }

    // MARK: - Scene graph

    private let dialRoot = SKNode()
    private let haloNode = SKSpriteNode(color: .clear, size: .zero)
    private let tickRingNode = SKSpriteNode(color: .clear, size: .zero)
    private let innerRingWideNode = SKSpriteNode(color: .clear, size: .zero)
    private let innerRingSmallNode = SKSpriteNode(color: .clear, size: .zero)
    private let fastArcRoot = SKNode()
    private let fastArcNode = SKSpriteNode(color: .clear, size: .zero)
    private let sweepRoot = SKNode()
    private let sweepNode = SKSpriteNode(color: .clear, size: .zero)
    private let sweepHeadNode = SKSpriteNode(color: .clear, size: .zero)
    private let centreGlowNode = SKSpriteNode(color: .clear, size: .zero)
    private let centreDotNode = SKSpriteNode(color: .clear, size: .zero)

    private var lastStyle: CalmSpaceRhythmStyle?
    private var isReducedMotion = false

    /// Base alphas (phase presence multiplies on top); they differ per theme because the
    /// light dial must sit on misty light, not glow like the dark one.
    private var baseAlpha: (halo: CGFloat, dial: CGFloat, glow: CGFloat, dot: CGFloat) {
        lastStyle?.isDark == true
            ? (halo: 0.50, dial: 0.60, glow: 0.55, dot: 0.90)
            : (halo: 0.40, dial: 0.68, glow: 0.40, dot: 0.80)
    }

    // MARK: - Lifecycle

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        buildDial()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    // MARK: - SwiftUI inputs

    /// Applies a new style. Diffed internally: equal styles are a no-op, geometry-only
    /// changes never restart an animation, and theme/phase changes never re-bake a
    /// texture (the white masks are cached and tinted at runtime).
    func apply(style: CalmSpaceRhythmStyle) {
        let previous = lastStyle
        let isFirst = previous == nil
        let phaseChanged = previous.map { $0.phase != style.phase } ?? true
        let themeChanged = isFirst || previous?.isDark != style.isDark
        let reduceMotionChanged = isFirst || previous?.reduceMotion != style.reduceMotion

        lastStyle = style
        isReducedMotion = style.reduceMotion

        applyGeometry(style: style)

        if themeChanged {
            applyPalette(CalmSpaceRhythmPalette.make(isDark: style.isDark), animated: !isFirst)
        }
        if isFirst || themeChanged || phaseChanged || reduceMotionChanged {
            applyMotion(style: style)
        }
    }

    // MARK: - Size / geometry

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0, let lastStyle else { return }
        // Always re-apply the exact style geometry (same rule as the orb scene): SwiftUI
        // can send the final style before the NSView adopted its new frame.
        applyGeometry(style: lastStyle)
    }

    /// Called by the host view after layout; covers the first layout where the scene was
    /// created before the view had a non-zero frame.
    func updateViewportLayout() {
        guard size.width > 0, size.height > 0 else { return }
        if let lastStyle {
            applyGeometry(style: lastStyle)
        }
    }

    private func applyGeometry(style: CalmSpaceRhythmStyle) {
        guard size.width > 0, size.height > 0 else { return }
        // `dialCenter` is SwiftUI top-left window coordinates; the scene is y-up, so the
        // flip happens exactly once here.
        dialRoot.position = CGPoint(x: style.dialCenter.x, y: size.height - style.dialCenter.y)
        // One uniform scale keeps the whole instrument circular at every window size.
        dialRoot.setScale(max(style.dialDiameter, 1) / Metrics.baseDiameter)
    }

    // MARK: - Scene graph

    private func buildDial() {
        dialRoot.zPosition = 0
        addChild(dialRoot)

        haloNode.zPosition = -4
        haloNode.size = CGSize(width: Metrics.baseDiameter, height: Metrics.baseDiameter)
        haloNode.texture = CalmSpaceRhythmTextures.texture(.halo)
        haloNode.colorBlendFactor = 1
        dialRoot.addChild(haloNode)

        tickRingNode.zPosition = -1
        tickRingNode.size = CGSize(width: Metrics.baseDiameter, height: Metrics.baseDiameter)
        tickRingNode.texture = CalmSpaceRhythmTextures.texture(.tickRing)
        tickRingNode.colorBlendFactor = 1
        dialRoot.addChild(tickRingNode)

        innerRingWideNode.zPosition = -2
        innerRingWideNode.size = CGSize(width: Metrics.baseDiameter, height: Metrics.baseDiameter)
        innerRingWideNode.texture = CalmSpaceRhythmTextures.texture(.innerRingWide)
        innerRingWideNode.colorBlendFactor = 1
        dialRoot.addChild(innerRingWideNode)

        innerRingSmallNode.zPosition = -2
        innerRingSmallNode.size = CGSize(width: Metrics.baseDiameter, height: Metrics.baseDiameter)
        innerRingSmallNode.texture = CalmSpaceRhythmTextures.texture(.innerRingSmall)
        innerRingSmallNode.colorBlendFactor = 1
        dialRoot.addChild(innerRingSmallNode)

        fastArcRoot.zPosition = 1
        dialRoot.addChild(fastArcRoot)
        fastArcNode.size = CGSize(width: Metrics.baseDiameter, height: Metrics.baseDiameter)
        fastArcNode.texture = CalmSpaceRhythmTextures.texture(.fastArc)
        fastArcNode.colorBlendFactor = 1
        fastArcRoot.addChild(fastArcNode)

        sweepRoot.zPosition = 2
        dialRoot.addChild(sweepRoot)
        sweepNode.size = CGSize(width: Metrics.baseDiameter, height: Metrics.baseDiameter)
        sweepNode.texture = CalmSpaceRhythmTextures.texture(.sweep)
        sweepNode.colorBlendFactor = 1
        sweepRoot.addChild(sweepNode)
        sweepHeadNode.position = CGPoint(x: 0, y: Metrics.sweepHeadRadius)
        sweepHeadNode.size = CGSize(
            width: Metrics.sweepHeadSize,
            height: Metrics.sweepHeadSize
        )
        sweepHeadNode.texture = CalmSpaceRhythmTextures.texture(.sweepHead)
        sweepHeadNode.colorBlendFactor = 1
        sweepRoot.addChild(sweepHeadNode)

        centreGlowNode.zPosition = 3
        centreGlowNode.size = CGSize(
            width: Metrics.centreGlowSize,
            height: Metrics.centreGlowSize
        )
        centreGlowNode.texture = CalmSpaceRhythmTextures.texture(.centreGlow)
        centreGlowNode.colorBlendFactor = 1
        dialRoot.addChild(centreGlowNode)

        centreDotNode.zPosition = 4
        centreDotNode.size = CGSize(width: Metrics.centreDotSize, height: Metrics.centreDotSize)
        centreDotNode.texture = CalmSpaceRhythmTextures.texture(.centreDot)
        centreDotNode.colorBlendFactor = 1
        dialRoot.addChild(centreDotNode)
    }

    // MARK: - Appearance

    private func applyPalette(_ palette: CalmSpaceRhythmPalette, animated: Bool) {
        // White masks tinted at runtime (same trick as the orb): a theme change is a
        // `SKAction.colorize` animation, never a new texture.
        let duration: TimeInterval = animated ? 0.6 : 0
        colorize(tickRingNode, to: palette.dialLine, duration: duration)
        colorize(innerRingWideNode, to: palette.dialLineSoft, duration: duration)
        colorize(innerRingSmallNode, to: palette.dialLineSoft, duration: duration)
        colorize(sweepNode, to: palette.accent, duration: duration)
        colorize(sweepHeadNode, to: palette.accent, duration: duration)
        colorize(fastArcNode, to: palette.hairlineAccent, duration: duration)
        colorize(haloNode, to: palette.halo, duration: duration)
        colorize(centreGlowNode, to: palette.centreGlow, duration: duration)
        colorize(centreDotNode, to: palette.centreDot, duration: duration)
    }

    private func colorize(_ node: SKSpriteNode, to color: NSColor, duration: TimeInterval) {
        guard duration > 0 else {
            node.color = color
            return
        }
        node.run(.sequence([.colorize(with: color, colorBlendFactor: 1, duration: duration)]))
    }

    // MARK: - Motion

    private func applyMotion(style: CalmSpaceRhythmStyle) {
        let motion = RhythmMotion.make(for: style.phase)
        let alphas = baseAlpha

        // Phase presence: `.focus` reads slightly more present, `.rest` softer. Always
        // re-applied so a phase/theme change never leaves stale alphas behind.
        haloNode.alpha = alphas.halo
        tickRingNode.alpha = alphas.dial
        innerRingWideNode.alpha = alphas.dial * 0.52
        innerRingSmallNode.alpha = alphas.dial * 0.34
        sweepNode.alpha = motion.sweepPresence
        sweepHeadNode.alpha = 0.9 * motion.sweepPresence
        fastArcNode.alpha = 0.5 * motion.fastArcPresence
        centreDotNode.alpha = alphas.dot

        sweepRoot.removeAllActions()
        fastArcRoot.removeAllActions()
        centreGlowNode.removeAllActions()

        if style.reduceMotion {
            // Reduce Motion: freeze every loop into a static composed dial. The pose is
            // intentionally asymmetric so the instrument still reads as "in use".
            sweepRoot.zRotation = Metrics.reducedSweepAngle
            fastArcRoot.zRotation = Metrics.reducedFastArcAngle
            centreGlowNode.setScale(1.0)
            centreGlowNode.alpha = alphas.glow * 0.8
            return
        }

        // Slow luminous sweep: one full revolution every ~2 minutes in the idle phase.
        sweepRoot.run(
            .repeatForever(.rotate(byAngle: -.pi * 2, duration: motion.sweepPeriod)),
            withKey: "sweep"
        )
        // The faint faster arc turns the other way for quiet liveliness.
        fastArcRoot.run(
            .repeatForever(.rotate(byAngle: .pi * 2, duration: motion.fastArcPeriod)),
            withKey: "fastArc"
        )

        // Centre breathing glow: gentle scale + fade over the phase's cycle.
        let half = motion.breathePeriod / 2
        let rest = alphas.glow * 0.45
        centreGlowNode.alpha = rest
        let sequence = SKAction.sequence([
            .group([
                .scale(to: 1.12, duration: half),
                .fadeAlpha(to: alphas.glow, duration: half),
            ]),
            .group([
                .scale(to: 1.0, duration: half),
                .fadeAlpha(to: rest, duration: half),
            ]),
        ])
        sequence.timingMode = .easeInEaseOut
        centreGlowNode.run(.repeatForever(sequence), withKey: "breathe")
    }
}

// MARK: - Texture cache

/// White-alpha Core Graphics masks, baked once per process and cached. Sizes never
/// depend on the window size, so neither a resize nor a theme switch re-bakes anything;
/// colour comes from `colorBlendFactor = 1` tinting at runtime.
private enum CalmSpaceRhythmTextures {
    enum Kind: Hashable {
        case halo
        case tickRing
        case innerRingWide
        case innerRingSmall
        case sweep
        case sweepHead
        case fastArc
        case centreGlow
        case centreDot
    }

    private static let dialCanvas = 512
    private static let glowCanvas = 128
    private static let smallCanvas = 64
    private static var cache: [Kind: SKTexture] = [:]

    static func texture(_ kind: Kind) -> SKTexture? {
        if let cached = cache[kind] { return cached }
        guard let texture = make(kind) else { return nil }
        cache[kind] = texture
        return texture
    }

    /// Dial-space → canvas-space conversion. Every full-dial texture maps the fixed
    /// 300-unit composition onto `dialCanvas` pixels.
    private static var unitsToPixels: CGFloat { CGFloat(dialCanvas) / 300 }

    private static func make(_ kind: Kind) -> SKTexture? {
        switch kind {
        case .halo:
            return makeRadialTexture(
                canvas: dialCanvas,
                stops: [
                    (0.00, white(0.55)),
                    (0.20, white(0.32)),
                    (0.45, white(0.13)),
                    (0.70, white(0.04)),
                    (1.00, white(0.00)),
                ]
            )
        case .tickRing:
            return makeTickRingTexture()
        case .innerRingWide:
            return makeHairlineCircleTexture(radius: 100)
        case .innerRingSmall:
            return makeHairlineCircleTexture(radius: 58)
        case .sweep:
            return makeSweepTexture()
        case .sweepHead:
            return makeRadialTexture(
                canvas: smallCanvas,
                stops: [
                    (0.00, white(1.00)),
                    (0.25, white(0.60)),
                    (0.55, white(0.18)),
                    (1.00, white(0.00)),
                ]
            )
        case .fastArc:
            return makeFastArcTexture()
        case .centreGlow:
            return makeRadialTexture(
                canvas: glowCanvas,
                stops: [
                    (0.00, white(0.80)),
                    (0.30, white(0.42)),
                    (0.65, white(0.12)),
                    (1.00, white(0.00)),
                ]
            )
        case .centreDot:
            return makeRadialTexture(
                canvas: smallCanvas,
                stops: [
                    (0.00, white(1.00)),
                    (0.45, white(0.90)),
                    (0.70, white(0.35)),
                    (1.00, white(0.00)),
                ]
            )
        }
    }

    // MARK: Dial bakes

    /// Outer hairline ring with 60 fine ticks; every 5th tick is longer and brighter.
    private static func makeTickRingTexture() -> SKTexture? {
        let canvas = dialCanvas
        let u = unitsToPixels
        let center = CGPoint(x: CGFloat(canvas) / 2, y: CGFloat(canvas) / 2)
        let outerRadius: CGFloat = 146 * u
        guard let context = makeBitmapContext(canvas: canvas) else { return nil }

        // Very soft bloom under the hairline so it reads as a fine instrument line,
        // not a neon circle.
        context.saveGState()
        context.setShadow(offset: .zero, blur: 3, color: white(0.22))
        context.setStrokeColor(white(0.75))
        context.setLineWidth(1.15)
        context.strokeEllipse(
            in: CGRect(
                x: center.x - outerRadius,
                y: center.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            )
        )
        context.restoreGState()

        for index in 0..<60 {
            let angle = CGFloat(index) / 60 * 2 * .pi
            let isMajor = index % 5 == 0
            let innerRadius: CGFloat = (isMajor ? 131 : 138.5) * u
            let tip = CGPoint(x: center.x + cos(angle) * outerRadius, y: center.y + sin(angle) * outerRadius)
            let inner = CGPoint(x: center.x + cos(angle) * innerRadius, y: center.y + sin(angle) * innerRadius)
            context.saveGState()
            context.setStrokeColor(white(isMajor ? 0.85 : 0.48))
            context.setLineWidth(isMajor ? 2.2 : 1.5)
            context.move(to: inner)
            context.addLine(to: tip)
            context.strokePath()
            context.restoreGState()
        }

        return finish(context)
    }

    /// A single hairline circle (baked at its own radius so both inner rings keep full
    /// resolution; the scene only fades them per depth).
    private static func makeHairlineCircleTexture(radius: CGFloat) -> SKTexture? {
        let canvas = dialCanvas
        let u = unitsToPixels
        let center = CGPoint(x: CGFloat(canvas) / 2, y: CGFloat(canvas) / 2)
        let pixelRadius = radius * u
        guard let context = makeBitmapContext(canvas: canvas) else { return nil }

        context.saveGState()
        context.setShadow(offset: .zero, blur: 2.4, color: white(0.18))
        context.setStrokeColor(white(0.70))
        context.setLineWidth(1.1)
        context.strokeEllipse(
            in: CGRect(
                x: center.x - pixelRadius,
                y: center.y - pixelRadius,
                width: pixelRadius * 2,
                height: pixelRadius * 2
            )
        )
        context.restoreGState()

        return finish(context)
    }

    /// The luminous sweep: a tapered comet-like arc at dial radius 120, tip pointing up
    /// (+y). The node rotates this around the centre; the separate soft head sprite sits
    /// at the tip.
    private static func makeSweepTexture() -> SKTexture? {
        let canvas = dialCanvas
        let u = unitsToPixels
        let center = CGPoint(x: CGFloat(canvas) / 2, y: CGFloat(canvas) / 2)
        let radius: CGFloat = 120 * u
        let tipAngle: CGFloat = .pi / 2
        let tailSpan: CGFloat = 0.95
        let segments = 26
        guard let context = makeBitmapContext(canvas: canvas) else { return nil }

        for index in 0..<segments {
            // 0 = tail, 1 = tip.
            let t = CGFloat(index) / CGFloat(segments - 1)
            let start = tipAngle - tailSpan * (1 - t)
            let end = min(start + tailSpan / CGFloat(segments) + 0.006, tipAngle)
            // Thin faint tail, thicker brighter near the head.
            let width = 0.6 + 3.0 * t * t
            let alpha = 0.05 + 0.72 * t * t
            context.saveGState()
            context.setShadow(offset: .zero, blur: 5, color: white(0.28))
            context.setStrokeColor(white(alpha))
            context.setLineWidth(width)
            let path = CGMutablePath()
            path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
            context.addPath(path)
            context.strokePath()
            context.restoreGState()
        }

        return finish(context)
    }

    /// A faint hairline arc at dial radius 72, tapered at both ends, tip pointing up.
    private static func makeFastArcTexture() -> SKTexture? {
        let canvas = dialCanvas
        let u = unitsToPixels
        let center = CGPoint(x: CGFloat(canvas) / 2, y: CGFloat(canvas) / 2)
        let radius: CGFloat = 72 * u
        let tipAngle: CGFloat = .pi / 2
        let span: CGFloat = 2.3
        let segments = 20
        guard let context = makeBitmapContext(canvas: canvas) else { return nil }

        for index in 0..<segments {
            let t = CGFloat(index) / CGFloat(segments - 1)
            let start = tipAngle - span * (1 - t)
            let end = min(start + span / CGFloat(segments) + 0.006, tipAngle)
            let taper = sin(.pi * t)
            context.saveGState()
            context.setShadow(offset: .zero, blur: 3, color: white(0.16))
            context.setStrokeColor(white(0.05 + 0.55 * taper))
            context.setLineWidth(1.2)
            let path = CGMutablePath()
            path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
            context.addPath(path)
            context.strokePath()
            context.restoreGState()
        }

        return finish(context)
    }

    // MARK: Bitmap helpers

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

    private static func drawRadial(
        _ context: CGContext,
        center: CGPoint,
        radius: CGFloat,
        stops: [(CGFloat, CGColor)]
    ) {
        guard radius > 0, let gradient = gradient(stops) else { return }
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: []
        )
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
