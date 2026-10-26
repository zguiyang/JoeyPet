import SwiftUI

#if DEBUG

// MARK: - Mac Care Stage body
//
// An abstract "system energy body" (a quiet digital planet). Built entirely from
// SwiftUI shapes, gradients, masks and blur — no SpriteKit, no shader, no Metal, no
// third-party animation library.
//
// Design rules enforced here:
//  * Asymmetric lighting: the key light sits at the upper-left (~35°); a soft terminator
//    falls across the lower-right. There is no centre hot-spot.
//  * Limb darkening: the outer ~10% of the disc falls off toward `bodyEdge`.
//  * Rim light: a single thin arc on the backlit (lower-right) side only — never a full
//    outline.
//  * Depth / translucency: a dark body + an offset, blurred atmosphere shell + a very
//    low-contrast inner flow, so the sphere has thickness rather than reading as one
//    radial gradient.
//  * One thin orbit band (~-16°) that passes behind the body; only the short front
//    segment (~30%) is drawn on top and it fades at both ends. A single ≤2.5 pt orbit
//    point sits below the body's brightness.
//
// Motion is low-frequency and cheap: breathing is a GPU transform via a repeating
// implicit animation; the travelling orbit point is the only TimelineView-driven drift
// (a few fps). Reduce Motion / `-JoeyPetQAStageFreeze` park everything at a fixed,
// deterministic phase.
struct MacCareStageBody: View {
    let material: MacCareStageMaterial
    let level: CalmSpaceHealthLevel
    let diameter: CGFloat
    let isDark: Bool
    let variant: CalmSpaceStageVariant
    let reduceMotion: Bool
    let freeze: Bool

    private var motion: MacCareStageMotion { .motion(for: level) }
    private var frozen: Bool { reduceMotion || freeze }

    /// Deterministic frozen orbit phase (matches a real phase value, for reproducible
    /// screenshots).
    private static let frozenOrbitAngle: CGFloat = .pi / 2.35

    @State private var breathing = false
    @State private var flowPulse = false

    // Orbit geometry (fixed so front/back occlusion is always correct).
    private let orbitTilt: CGFloat = -16 * .pi / 180

    var body: some View {
        let r = diameter / 2
        let extent = diameter * 1.78

        Group {
            if variant == .b {
                variantB(radius: r)
            } else {
                variantA(radius: r)
            }
        }
        .frame(width: extent, height: extent)
        .onAppear {
            guard !frozen else { return }
            withAnimation(
                .easeInOut(duration: motion.breathPeriod)
                    .repeatForever(autoreverses: true)
            ) {
                breathing = true
            }
            withAnimation(
                .easeInOut(duration: motion.breathPeriod * 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                flowPulse = true
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Variant A (shipped): refined digital planet

    private func variantA(radius: CGFloat) -> some View {
        ZStack {
            atmosphereShell(radius: radius)

            orbitBack(radius: radius)

            sphere(radius: radius)
                .scaleEffect(frozen ? 1.0 : 1.0 + motion.breathAmplitude * (breathing ? 1 : 0))

            orbitFront(radius: radius)

            orbitPointView(radius: radius)
        }
    }

    // MARK: - Variant B (exploration): horizon / atmosphere-band energy body

    /// A quieter alternative: no orbit ring. Light rakes in from the upper-left and pools
    /// into a bright horizon band along that limb, with the rest of the disc falling into
    /// shadow — a "sunrise over a planet limb" read. Same breathing and semantic tint as A.
    private func variantB(radius: CGFloat) -> some View {
        ZStack {
            // Outer atmosphere haze, biased toward the lit (upper-left) limb.
            Ellipse()
                .fill(material.atmosphere.opacity(isDark ? 0.30 : 0.22))
                .frame(width: diameter + 16, height: diameter + 10)
                .offset(x: -diameter * 0.05, y: -diameter * 0.04)
                .blur(radius: 16)

            horizonBody(radius: radius)
                .scaleEffect(frozen ? 1.0 : 1.0 + motion.breathAmplitude * (breathing ? 1 : 0))
        }
    }

    private func horizonBody(radius: CGFloat) -> some View {
        ZStack {
            // Shadow-dominant base; brightness pools toward the upper-left limb.
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: material.bodyEdge, location: 0.0),
                            .init(color: material.bodyDeep, location: 0.36),
                            .init(color: material.bodyMid, location: 0.70),
                            .init(color: material.bodyLit.opacity(0.92), location: 0.93),
                            .init(color: material.atmosphere.opacity(isDark ? 0.85 : 0.78), location: 1.0),
                        ]),
                        center: UnitPoint(x: 0.74, y: 0.80),
                        startRadius: 0,
                        endRadius: radius * 1.62
                    )
                )
                .frame(width: diameter, height: diameter)

            // Very low-contrast inner flow for thickness.
            innerFlow
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())

            // Crisp lit horizon along the upper-left limb.
            horizonLimb(radius: radius)
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())

            // A whisper of backlit rim on the shadow side.
            rimLight(radius: radius)
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
        }
    }

    /// A thin, bright arc hugging the upper-left (lit) limb — the horizon line.
    private func horizonLimb(radius: CGFloat) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let rr = radius * 0.965
            let start: CGFloat = 196
            let end: CGFloat = 262
            let steps = 48
            var path = Path()
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let angle = (start + (end - start) * t) * .pi / 180
                let p = CGPoint(x: center.x + rr * cos(angle), y: center.y + rr * sin(angle))
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            context.stroke(path, with: .color(material.rimLight.opacity(isDark ? 0.9 : 0.8)),
                           style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            context.stroke(path, with: .color(material.atmosphere.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 6.0, lineCap: .round))
        }
        .blur(radius: 0.6)
    }

    // MARK: - Atmosphere shell (behind body)

    /// A soft, blurred halo a few points larger than the disc. It reads as a translucent
    /// outer atmosphere and gives the body real thickness against the background. In the
    /// light theme this must stay a *matte* edge, not a cheap glow ring, so it is thin and
    /// quiet there.
    private func atmosphereShell(radius: CGFloat) -> some View {
        // Light theme keeps only a crisp matte edge (no halo); dark keeps a faint shell.
        let light = !isDark
        return Circle()
            .fill(material.atmosphere.opacity(light ? 0.09 : 0.30))
            .frame(width: diameter + (light ? 4 : 10), height: diameter + (light ? 4 : 10))
            .blur(radius: light ? 8 : 12)
            .opacity(frozen ? 1 : (flowPulse ? 1.0 : 0.9))
    }

    // MARK: - Sphere

    private func sphere(radius: CGFloat) -> some View {
        ZStack {
            // Base: offset radial gradient (asymmetric key light) with limb darkening.
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: material.bodyLit, location: 0.0),
                            .init(color: material.bodyMid, location: 0.40),
                            .init(color: material.bodyDeep, location: 0.80),
                            .init(color: material.bodyEdge, location: 1.0),
                        ]),
                        center: UnitPoint(x: 0.36, y: 0.32),
                        startRadius: 0,
                        endRadius: radius * 1.30
                    )
                )
                .frame(width: diameter, height: diameter)

            // Terminator: deepen the lower-right shadow, anchored to the key light.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.clear, material.bodyDeep.opacity(isDark ? 0.5 : 0.42)],
                        center: UnitPoint(x: 0.36, y: 0.32),
                        startRadius: radius * 0.45,
                        endRadius: radius * 1.16
                    )
                )
                .frame(width: diameter, height: diameter)

            // Inner flow: very low-contrast drifting light, clipped to the disc.
            innerFlow
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())

            // Atmospheric limb: a faint brightening right at the edge for depth.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.clear, material.atmosphere.opacity(isDark ? 0.20 : 0.16)],
                        center: .center,
                        startRadius: radius * 0.80,
                        endRadius: radius
                    )
                )
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())

            // Rim light: one thin backlit arc on the lower-right only.
            rimLight(radius: radius)
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
        }
        .animation(.easeInOut(duration: 1.0), value: level)
    }

    /// A single, edge-free radial glow in the same direction as the key light, fading
    /// smoothly to `.clear` across the whole disc. Because it is a gradient (not a blurred
    /// shape), it leaves no recognisable circle/ellipse boundary inside the sphere — it
    /// only adds a whisper of thickness. Pulse the group opacity slowly.
    private var innerFlow: some View {
        let pulse = frozen ? 1.0 : (flowPulse ? 1.0 : 0.82)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [material.innerFlow.opacity(isDark ? 0.10 : 0.08), .clear],
                    center: UnitPoint(x: 0.40, y: 0.36),   // same direction as the key light
                    startRadius: 0,
                    endRadius: diameter * 0.55
                )
            )
            .frame(width: diameter, height: diameter)
            .opacity(pulse)
    }

    /// A single thin, blurred arc hugging the lower-right limb. Not a full outline —
    /// quiet (main 0.45, soft 0.14) and short (~55°), so it reads as a wrapped rim.
    private func rimLight(radius: CGFloat) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let rimRadius = radius * 0.955
            // Screen angles: 0° = +x (right), 90° = +y (down). Backlit side ~ down-right.
            let start: CGFloat = 14
            let end: CGFloat = 69   // ~55° arc
            let steps = 40
            var path = Path()
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let angle = (start + (end - start) * t) * .pi / 180
                let p = CGPoint(
                    x: center.x + rimRadius * cos(angle),
                    y: center.y + rimRadius * sin(angle)
                )
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            context.stroke(path, with: .color(material.rimLight.opacity(0.45)),
                           style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            // Soften with a slightly wider, dimmer pass.
            context.stroke(path, with: .color(material.rimLight.opacity(0.14)),
                           style: StrokeStyle(lineWidth: 3.7, lineCap: .round))
        }
        .blur(radius: 0.5)
    }

    // MARK: - Orbit

    /// Point on the orbit ellipse at parameter `theta`, around the *real* canvas centre
    /// `center` (the orbit canvases fill the whole `extent × extent` frame, so the centre
    /// is `size/2`, not `(radius, radius)` — using the latter offset the whole ring up-left).
    private func ellipsePoint(_ theta: CGFloat, radius: CGFloat, center: CGPoint) -> CGPoint {
        let a = radius * 1.31   // 1.28–1.34r: a readable orbit that clears the limb
        let b = radius * 0.36   // 0.34–0.38r
        let x = a * cos(theta)
        let y = b * sin(theta)
        let rx = x * cos(orbitTilt) - y * sin(orbitTilt)
        let ry = x * sin(orbitTilt) + y * cos(orbitTilt)
        return CGPoint(x: center.x + rx, y: center.y + ry)
    }

    /// Parameter of the ellipse point with the greatest screen-y (the front-most point).
    private func frontTheta(radius: CGFloat, center: CGPoint) -> CGFloat {
        var best: CGFloat = 0
        var bestY: CGFloat = -CGFloat.greatestFiniteMagnitude
        var t: CGFloat = 0
        while t < 2 * .pi {
            let p = ellipsePoint(t, radius: radius, center: center)
            if p.y > bestY { bestY = p.y; best = t }
            t += 0.02
        }
        return best
    }

    /// The full orbit band, drawn *behind* the body so the disc occludes its middle.
    private func orbitBack(radius: CGFloat) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let path = ellipsePath(radius: radius, center: center)
            let base: CGFloat = isDark ? 0.20 : 0.22
            context.stroke(
                path,
                with: .color(material.orbitLine.opacity(base)),
                style: StrokeStyle(lineWidth: 1.0, lineCap: .round)
            )
        }
    }

    private func ellipsePath(radius: CGFloat, center: CGPoint) -> Path {
        var path = Path()
        let steps = 128
        for i in 0...steps {
            let theta = CGFloat(i) / CGFloat(steps) * 2 * .pi
            let p = ellipsePoint(theta, radius: radius, center: center)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    /// Only the short front segment of the orbit, drawn on top of the body and faded at
    /// both ends (~25% of the band) so it hands off naturally to the back segment at the
    /// sides. `critical` lifts its leading brightness slightly (still below the body).
    private func orbitFront(radius: CGFloat) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let centerTheta = frontTheta(radius: radius, center: center)
            let halfSpan = 0.32 * .pi   // ~32% of the band, crossing the lower limb
            let segments = 60
            let peak = (isDark ? 0.46 : 0.44) + material.orbitFrontBoost * 0.05
            for i in 0..<segments {
                let t0 = CGFloat(i) / CGFloat(segments)
                let t1 = CGFloat(i + 1) / CGFloat(segments)
                let a0 = centerTheta + (t0 - 0.5) * 2 * halfSpan
                let a1 = centerTheta + (t1 - 0.5) * 2 * halfSpan
                let mid = (t0 + t1) / 2
                let alpha = peak * sin(.pi * mid)   // 0 at ends, peak at centre
                guard alpha > 0.01 else { continue }
                var seg = Path()
                seg.move(to: ellipsePoint(a0, radius: radius, center: center))
                seg.addLine(to: ellipsePoint(a1, radius: radius, center: center))
                context.stroke(
                    seg,
                    with: .color(material.orbitLine.opacity(alpha)),
                    style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
                )
            }
        }
    }

    /// A single ≤2.5 pt orbit point travelling along the fixed band. Brightest at the
    /// front-most point and faded out as it slips behind the body. TimelineView-driven
    /// only when not frozen; the point itself is tiny, so the redraw cost is negligible.
    @ViewBuilder
    private func orbitPointView(radius: CGFloat) -> some View {
        if frozen {
            orbitPointCanvas(radius: radius, angle: Self.frozenOrbitAngle)
        } else {
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let angle = Self.frozenOrbitAngle
                    + CGFloat(t.truncatingRemainder(dividingBy: motion.orbitPeriod) / motion.orbitPeriod) * 2 * .pi
                orbitPointCanvas(radius: radius, angle: angle)
            }
        }
    }

    private func orbitPointCanvas(radius: CGFloat, angle: CGFloat) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let centerTheta = frontTheta(radius: radius, center: center)
            let halfSpan = 0.32 * .pi
            // Angular distance from the front-most point.
            var d = abs(Self.wrapAngle(angle - centerTheta))
            guard d < halfSpan else { return }
            let alpha = cos(d / halfSpan * .pi / 2)
            let p = ellipsePoint(angle, radius: radius, center: center)
            let dot = CGRect(x: p.x - 1.25, y: p.y - 1.25, width: 2.5, height: 2.5)
            context.fill(
                Path(ellipseIn: dot),
                with: .color(material.orbitPoint.opacity(alpha * (isDark ? 0.9 : 0.8)))
            )
            // Faint halo, still below body brightness.
            context.fill(
                Path(ellipseIn: dot.insetBy(dx: -2, dy: -2)),
                with: .color(material.orbitPoint.opacity(alpha * 0.22))
            )
        }
    }

    /// Wraps an angle into (-π, π].
    private static func wrapAngle(_ a: CGFloat) -> CGFloat {
        var x = a.truncatingRemainder(dividingBy: 2 * .pi)
        if x > .pi { x -= 2 * .pi }
        if x < -CGFloat.pi { x += 2 * .pi }
        return x
    }
}

#endif
