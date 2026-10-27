import AppKit
import SwiftUI

/// Calm Space visual tokens.
///
/// Light and dark are tuned independently: light is a misty morning space, not an
/// inverted dark palette. Semantic accents are for status only; the orb keeps its
/// own material and borrows only a small amount of the status colour.
struct CalmSpacePalette {
    let isDark: Bool

    let backgroundTop: Color
    let backgroundMid: Color
    let backgroundBottom: Color
    let ambientPrimary: Color
    let ambientSecondary: Color
    let starColor: Color

    let orbCore: Color
    let orbMid: Color
    let orbDeep: Color
    let orbEdge: Color
    let orbGlow: Color
    let orbInner: Color
    let orbHighlight: Color
    let orbitLine: Color
    let orbitParticle: Color

    let normalAccent: Color
    let attentionAccent: Color
    let criticalAccent: Color
    let unknownAccent: Color

    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    /// Status block meta line only (11 pt). Tuned to stay ≥ 4.5:1 on the composited
    /// page background without lifting the shared `tertiaryText` used elsewhere.
    let statusMetaText: Color

    let controlFill: Color
    let controlHoverFill: Color
    let controlStroke: Color
    let controlHoverStroke: Color

    static func palette(for colorScheme: ColorScheme) -> CalmSpacePalette {
        colorScheme == .dark ? .dark : .light
    }

    func accent(for level: CalmSpaceHealthLevel) -> Color {
        switch level {
        case .normal: return normalAccent
        case .attention: return attentionAccent
        case .critical: return criticalAccent
        case .unknown: return unknownAccent
        }
    }
}

extension CalmSpacePalette {
    static let dark = CalmSpacePalette(
        isDark: true,
        backgroundTop: Color(red: 0.031, green: 0.055, blue: 0.098),
        backgroundMid: Color(red: 0.020, green: 0.038, blue: 0.071),
        backgroundBottom: Color(red: 0.012, green: 0.024, blue: 0.047),
        ambientPrimary: Color(red: 0.145, green: 0.500, blue: 0.520),
        ambientSecondary: Color(red: 0.160, green: 0.320, blue: 0.620),
        starColor: Color(red: 0.78, green: 0.87, blue: 1.0),
        orbCore: Color(red: 0.55, green: 0.95, blue: 0.88),
        orbMid: Color(red: 0.20, green: 0.63, blue: 0.80),
        orbDeep: Color(red: 0.05, green: 0.19, blue: 0.35),
        orbEdge: Color(red: 0.49, green: 0.91, blue: 0.86),
        orbGlow: Color(red: 0.38, green: 0.85, blue: 0.82),
        orbInner: Color(red: 0.62, green: 0.96, blue: 0.92),
        orbHighlight: Color(red: 0.85, green: 0.98, blue: 0.97),
        orbitLine: Color(red: 0.62, green: 0.79, blue: 0.92),
        orbitParticle: Color(red: 0.80, green: 0.97, blue: 0.94),
        normalAccent: Color(red: 0.52, green: 0.90, blue: 0.84),
        attentionAccent: Color(red: 0.92, green: 0.72, blue: 0.42),
        criticalAccent: Color(red: 0.93, green: 0.55, blue: 0.51),
        unknownAccent: Color(red: 0.63, green: 0.71, blue: 0.80),
        primaryText: Color(red: 0.95, green: 0.97, blue: 1.0),
        secondaryText: Color(red: 0.84, green: 0.90, blue: 0.98).opacity(0.68),
        tertiaryText: Color(red: 0.80, green: 0.87, blue: 0.96).opacity(0.44),
        statusMetaText: Color(red: 0.80, green: 0.87, blue: 0.96).opacity(0.60),
        controlFill: Color.white.opacity(0.055),
        controlHoverFill: Color.white.opacity(0.11),
        controlStroke: Color.white.opacity(0.10),
        controlHoverStroke: Color.white.opacity(0.18)
    )

    static let light = CalmSpacePalette(
        isDark: false,
        backgroundTop: Color(red: 0.973, green: 0.984, blue: 0.996),
        backgroundMid: Color(red: 0.914, green: 0.949, blue: 0.980),
        backgroundBottom: Color(red: 0.847, green: 0.902, blue: 0.957),
        ambientPrimary: Color(red: 0.690, green: 0.851, blue: 0.945),
        ambientSecondary: Color(red: 0.788, green: 0.878, blue: 0.957),
        starColor: Color(red: 0.353, green: 0.514, blue: 0.650),
        orbCore: Color(red: 0.855, green: 0.969, blue: 0.988),
        orbMid: Color(red: 0.431, green: 0.765, blue: 0.906),
        orbDeep: Color(red: 0.235, green: 0.525, blue: 0.737),
        orbEdge: Color(red: 0.851, green: 0.957, blue: 1.0),
        orbGlow: Color(red: 0.561, green: 0.839, blue: 0.941),
        orbInner: Color(red: 0.941, green: 0.988, blue: 1.0),
        orbHighlight: Color.white,
        orbitLine: Color(red: 0.498, green: 0.663, blue: 0.788),
        orbitParticle: Color.white,
        normalAccent: Color(red: 0.165, green: 0.616, blue: 0.580),
        attentionAccent: Color(red: 0.690, green: 0.455, blue: 0.165),
        criticalAccent: Color(red: 0.761, green: 0.329, blue: 0.306),
        unknownAccent: Color(red: 0.420, green: 0.494, blue: 0.561),
        primaryText: Color(red: 0.075, green: 0.125, blue: 0.180),
        secondaryText: Color(red: 0.075, green: 0.125, blue: 0.180).opacity(0.64),
        tertiaryText: Color(red: 0.075, green: 0.125, blue: 0.180).opacity(0.42),
        statusMetaText: Color(red: 0.075, green: 0.125, blue: 0.180).opacity(0.65),
        controlFill: Color.white.opacity(0.58),
        controlHoverFill: Color.white.opacity(0.84),
        controlStroke: Color.black.opacity(0.06),
        controlHoverStroke: Color.black.opacity(0.12)
    )
}

// MARK: - Orb bridge

/// Input for the SpriteKit ambient layer. Everything animates in one scene so the
/// window keeps a single render loop at 30 FPS.
struct CalmSpaceOrbStyle: Equatable {
    let isDark: Bool
    let health: CalmSpaceHealthLevel
    let mode: AppMode
    let reduceMotion: Bool
    let orbDiameter: CGFloat
    let orbCenter: CGPoint
}

/// `NSColor` values derived from the palette. Textures are grayscale and tinted, so
/// theme / health changes never need a new render pass.
struct CalmSpaceOrbPalette {
    let isDark: Bool
    let health: CalmSpaceHealthLevel
    let mode: AppMode

    let core: NSColor
    let mid: NSColor
    let deep: NSColor
    let edge: NSColor
    let glow: NSColor
    let inner: NSColor
    let highlight: NSColor
    let orbitLine: NSColor
    let particle: NSColor
    let ambientPrimary: NSColor
    let ambientSecondary: NSColor
    let star: NSColor

    static func make(style: CalmSpaceOrbStyle) -> CalmSpaceOrbPalette {
        let palette = CalmSpacePalette.palette(for: style.isDark ? .dark : .light)
        let workBlend: CGFloat = style.mode == .workRhythm
            ? (style.health == .normal ? 0.22 : 0.10)
            : 0
        let workTint = NSColor(red: 0.40, green: 0.50, blue: 0.94, alpha: 1)

        func mix(_ color: NSColor, with tint: NSColor, _ fraction: CGFloat) -> NSColor {
            guard fraction > 0 else { return color }
            return color.blended(withFraction: fraction, of: tint) ?? color
        }

        // Healthy state keeps the blue-green material; attention/critical/unknown use
        // explicitly tuned warm/coral/neutral materials. Blending teal with amber would
        // produce a muddy grey-mauve orb, so semantic states do not derive from the base
        // by hue rotation.
        if let material = SemanticOrbMaterial.material(for: style.health, isDark: style.isDark) {
            func finish(_ color: NSColor, work: CGFloat = 1) -> NSColor {
                mix(color, with: workTint, workBlend * work)
            }
            return CalmSpaceOrbPalette(
                isDark: style.isDark,
                health: style.health,
                mode: style.mode,
                core: finish(material.core),
                mid: finish(material.mid),
                deep: finish(material.deep),
                edge: finish(material.edge),
                glow: finish(material.glow),
                inner: finish(material.inner),
                highlight: finish(material.highlight, work: 0.3),
                orbitLine: finish(material.orbitLine),
                particle: finish(material.particle),
                ambientPrimary: NSColor(palette.ambientPrimary),
                ambientSecondary: NSColor(palette.ambientSecondary),
                star: NSColor(palette.starColor)
            )
        }

        func material(_ color: Color, work: CGFloat = 1) -> NSColor {
            mix(NSColor(color), with: workTint, workBlend * work)
        }

        return CalmSpaceOrbPalette(
            isDark: style.isDark,
            health: style.health,
            mode: style.mode,
            core: material(palette.orbCore),
            mid: material(palette.orbMid),
            deep: material(palette.orbDeep),
            edge: material(palette.orbEdge),
            glow: material(palette.orbGlow),
            inner: material(palette.orbInner),
            highlight: material(palette.orbHighlight, work: 0.3),
            orbitLine: material(palette.orbitLine),
            particle: material(palette.orbitParticle),
            ambientPrimary: NSColor(palette.ambientPrimary),
            ambientSecondary: NSColor(palette.ambientSecondary),
            star: NSColor(palette.starColor)
        )
    }
}

// MARK: - Semantic orb materials

private struct SemanticOrbMaterial {
    let core: NSColor
    let mid: NSColor
    let deep: NSColor
    let edge: NSColor
    let glow: NSColor
    let inner: NSColor
    let highlight: NSColor
    let orbitLine: NSColor
    let particle: NSColor

    static func material(
        for health: CalmSpaceHealthLevel,
        isDark: Bool
    ) -> SemanticOrbMaterial? {
        switch (health, isDark) {
        case (.attention, true):
            return SemanticOrbMaterial(
                core: NSColor(red: 0.94, green: 0.82, blue: 0.62, alpha: 1),
                mid: NSColor(red: 0.78, green: 0.56, blue: 0.30, alpha: 1),
                deep: NSColor(red: 0.24, green: 0.14, blue: 0.08, alpha: 1),
                edge: NSColor(red: 0.95, green: 0.78, blue: 0.48, alpha: 1),
                glow: NSColor(red: 0.85, green: 0.63, blue: 0.34, alpha: 1),
                inner: NSColor(red: 0.98, green: 0.90, blue: 0.74, alpha: 1),
                highlight: NSColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1),
                orbitLine: NSColor(red: 0.82, green: 0.70, blue: 0.50, alpha: 1),
                particle: NSColor(red: 0.98, green: 0.88, blue: 0.66, alpha: 1)
            )
        case (.critical, true):
            return SemanticOrbMaterial(
                core: NSColor(red: 0.95, green: 0.75, blue: 0.71, alpha: 1),
                mid: NSColor(red: 0.78, green: 0.38, blue: 0.35, alpha: 1),
                deep: NSColor(red: 0.26, green: 0.10, blue: 0.10, alpha: 1),
                edge: NSColor(red: 0.95, green: 0.65, blue: 0.61, alpha: 1),
                glow: NSColor(red: 0.88, green: 0.48, blue: 0.45, alpha: 1),
                inner: NSColor(red: 0.99, green: 0.84, blue: 0.80, alpha: 1),
                highlight: NSColor(red: 1.0, green: 0.93, blue: 0.90, alpha: 1),
                orbitLine: NSColor(red: 0.80, green: 0.56, blue: 0.53, alpha: 1),
                particle: NSColor(red: 0.98, green: 0.78, blue: 0.74, alpha: 1)
            )
        case (.unknown, true):
            return SemanticOrbMaterial(
                core: NSColor(red: 0.72, green: 0.78, blue: 0.84, alpha: 1),
                mid: NSColor(red: 0.40, green: 0.48, blue: 0.56, alpha: 1),
                deep: NSColor(red: 0.10, green: 0.14, blue: 0.19, alpha: 1),
                edge: NSColor(red: 0.60, green: 0.68, blue: 0.76, alpha: 1),
                glow: NSColor(red: 0.50, green: 0.58, blue: 0.66, alpha: 1),
                inner: NSColor(red: 0.82, green: 0.87, blue: 0.92, alpha: 1),
                highlight: NSColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1),
                orbitLine: NSColor(red: 0.60, green: 0.67, blue: 0.74, alpha: 1),
                particle: NSColor(red: 0.85, green: 0.90, blue: 0.95, alpha: 1)
            )
        case (.attention, false):
            return SemanticOrbMaterial(
                core: NSColor(red: 1.0, green: 0.97, blue: 0.90, alpha: 1),
                mid: NSColor(red: 0.87, green: 0.67, blue: 0.39, alpha: 1),
                deep: NSColor(red: 0.55, green: 0.36, blue: 0.16, alpha: 1),
                edge: NSColor(red: 0.97, green: 0.87, blue: 0.68, alpha: 1),
                glow: NSColor(red: 0.91, green: 0.72, blue: 0.43, alpha: 1),
                inner: NSColor(red: 1.0, green: 0.99, blue: 0.96, alpha: 1),
                highlight: .white,
                orbitLine: NSColor(red: 0.72, green: 0.59, blue: 0.42, alpha: 1),
                particle: NSColor(red: 1.0, green: 0.98, blue: 0.92, alpha: 1)
            )
        case (.critical, false):
            return SemanticOrbMaterial(
                core: NSColor(red: 1.0, green: 0.94, blue: 0.92, alpha: 1),
                mid: NSColor(red: 0.88, green: 0.52, blue: 0.49, alpha: 1),
                deep: NSColor(red: 0.55, green: 0.24, blue: 0.22, alpha: 1),
                edge: NSColor(red: 0.96, green: 0.80, blue: 0.76, alpha: 1),
                glow: NSColor(red: 0.92, green: 0.62, blue: 0.58, alpha: 1),
                inner: NSColor(red: 1.0, green: 0.97, blue: 0.96, alpha: 1),
                highlight: .white,
                orbitLine: NSColor(red: 0.73, green: 0.49, blue: 0.46, alpha: 1),
                particle: NSColor(red: 1.0, green: 0.92, blue: 0.90, alpha: 1)
            )
        case (.unknown, false):
            return SemanticOrbMaterial(
                core: NSColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1),
                mid: NSColor(red: 0.68, green: 0.75, blue: 0.82, alpha: 1),
                deep: NSColor(red: 0.36, green: 0.43, blue: 0.50, alpha: 1),
                edge: NSColor(red: 0.88, green: 0.92, blue: 0.95, alpha: 1),
                glow: NSColor(red: 0.76, green: 0.82, blue: 0.88, alpha: 1),
                inner: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                highlight: .white,
                orbitLine: NSColor(red: 0.55, green: 0.62, blue: 0.69, alpha: 1),
                particle: .white
            )
        case (.normal, _):
            return nil
        }
    }
}

// MARK: - Work Rhythm bridge

/// Work Rhythm phase.
///
/// `.idle` is the only phase the UI may select in V1: Work Rhythm has no running timer
/// yet, so the dial only communicates "time is flowing". `.focus` / `.rest` are
/// documented, inert branches of the rhythm scene (focus = a steadier, slightly more
/// present sweep; rest = a slower, softer one) and must not be wired up until real
/// session state exists. No phase ever displays a countdown or progress values.
enum CalmSpaceRhythmPhase: Equatable {
    case idle
    case focus
    case rest
}

/// Input for the Work Rhythm SpriteKit layer. Everything animates in one scene so the
/// page keeps a single render loop at 30 FPS.
struct CalmSpaceRhythmStyle: Equatable {
    let phase: CalmSpaceRhythmPhase
    /// Reserved for a future real session. `nil` — the only value the UI may pass in V1
    /// — renders exactly the phase dial described in `CalmSpaceRhythmScene`; a future
    /// value must never be interpreted as a countdown by the visuals.
    let progress: Double?
    let isDark: Bool
    let reduceMotion: Bool
    let dialDiameter: CGFloat
    let dialCenter: CGPoint
}

/// `NSColor` values for the Work Rhythm dial, derived from `CalmSpacePalette` with a few
/// per-theme tuning values where the shared tokens have no equivalent (dial line,
/// accent/sweep, halo, centre dot). Light is cool slate/steel-blue hairlines on misty
/// light — a real light design, not a dimmed dark theme; dark is calm luminous mint/ice
/// on deep space.
struct CalmSpaceRhythmPalette {
    let isDark: Bool
    /// Outer tick ring.
    let dialLine: NSColor
    /// Fainter inner concentric circles.
    let dialLineSoft: NSColor
    /// The luminous sweep + its head.
    let accent: NSColor
    /// The fainter, faster hairline arc.
    let hairlineAccent: NSColor
    /// Soft radial halo behind the dial.
    let halo: NSColor
    /// Quiet centre dot.
    let centreDot: NSColor
    /// Centre breathing glow.
    let centreGlow: NSColor

    static func make(isDark: Bool) -> CalmSpaceRhythmPalette {
        let palette = CalmSpacePalette.palette(for: isDark ? .dark : .light)

        if isDark {
            // Calm luminous mint/ice on deep space: dial lines borrow the starfield ice,
            // the sweep is the orb's mint core made precise.
            return CalmSpaceRhythmPalette(
                isDark: true,
                dialLine: NSColor(palette.starColor),
                dialLineSoft: NSColor(red: 0.55, green: 0.66, blue: 0.82, alpha: 1),
                accent: NSColor(palette.orbCore),
                hairlineAccent: NSColor(red: 0.62, green: 0.79, blue: 0.92, alpha: 1),
                halo: NSColor(palette.ambientPrimary),
                centreDot: NSColor(palette.orbInner),
                centreGlow: NSColor(palette.orbGlow)
            )
        }

        // Cool slate/steel-blue hairlines on misty light. The sweep uses the darker
        // teal accent (same family as the status accent) so it stays legible on a light
        // ground instead of glowing white.
        return CalmSpaceRhythmPalette(
            isDark: false,
            dialLine: NSColor(red: 0.30, green: 0.44, blue: 0.58, alpha: 1),
            dialLineSoft: NSColor(red: 0.45, green: 0.58, blue: 0.70, alpha: 1),
            accent: NSColor(red: 0.13, green: 0.52, blue: 0.50, alpha: 1),
            hairlineAccent: NSColor(palette.orbitLine),
            halo: NSColor(palette.ambientPrimary),
            centreDot: NSColor(red: 0.13, green: 0.52, blue: 0.50, alpha: 1),
            centreGlow: NSColor(red: 0.35, green: 0.66, blue: 0.76, alpha: 1)
        )
    }
}
