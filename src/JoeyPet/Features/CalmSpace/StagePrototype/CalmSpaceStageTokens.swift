import SwiftUI

#if DEBUG

// MARK: - Stage theme tokens
//
// Design tokens for the new Mac Care "Stage" prototype. These are a superset of the
// existing `CalmSpacePalette` roles and are tuned so the two themes read as materials,
// not as an inversion of one another: light is a cool porcelain morning body, dark is a
// deep ocean-night body. Every colour lives here — views never hold a `Color(red:...)`
// magic value.
//
// All values are DEBUG-prototype only for now (Unit 1). Unit 2 promotes the shared
// subset into the production palette with an ADR; nothing here touches production yet.
struct MacCareStageTokens {
    let isDark: Bool

    // Body surface (asymmetric-light sphere material).
    let bodyLit: Color       // lit side, upper-left — soft, never pure white
    let bodyMid: Color       // mid tone across the terminator
    let bodyDeep: Color      // shadow side / limb
    let bodyEdge: Color      // crisp edge just inside the limb

    // Depth / translucency.
    let atmosphere: Color    // offset translucent shell / haze
    let innerFlow: Color     // very low-contrast internal drift

    // Rim light (thin backlit arc on the shadow side only).
    let rimLight: Color

    // Orbit.
    let orbitLine: Color
    let orbitPoint: Color

    // Decoration.
    let star: Color

    // Semantic accents — tuned independently per theme and per state.
    let normalAccent: Color
    let attentionAccent: Color
    let criticalAccent: Color
    let unknownAccent: Color

    // Typography.
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color

    // Controls / hairlines / progress.
    let chipStroke: Color
    let chipFill: Color
    let progressTrack: Color
    let progressFill: Color
    let connectorLine: Color

    static func tokens(for colorScheme: ColorScheme) -> MacCareStageTokens {
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

extension MacCareStageTokens {
    // Dark: a deep ocean-night body. The lit side is a cool seafoam that stays well
    // below white so the upper-left never becomes a hot spot.
    static let dark = MacCareStageTokens(
        isDark: true,
        bodyLit: Color(red: 0.42, green: 0.72, blue: 0.74),
        bodyMid: Color(red: 0.13, green: 0.31, blue: 0.42),
        bodyDeep: Color(red: 0.035, green: 0.086, blue: 0.153),
        bodyEdge: Color(red: 0.020, green: 0.055, blue: 0.106),
        atmosphere: Color(red: 0.34, green: 0.64, blue: 0.70),
        innerFlow: Color(red: 0.52, green: 0.82, blue: 0.83),
        rimLight: Color(red: 0.66, green: 0.86, blue: 0.90),
        orbitLine: Color(red: 0.55, green: 0.70, blue: 0.82),
        orbitPoint: Color(red: 0.78, green: 0.90, blue: 0.95),
        star: Color(red: 0.80, green: 0.88, blue: 0.97),
        normalAccent: Color(red: 0.44, green: 0.85, blue: 0.78),
        attentionAccent: Color(red: 0.93, green: 0.71, blue: 0.42),
        criticalAccent: Color(red: 0.95, green: 0.55, blue: 0.50),
        unknownAccent: Color(red: 0.62, green: 0.71, blue: 0.80),
        primaryText: Color(red: 0.95, green: 0.97, blue: 1.0),
        secondaryText: Color(red: 0.86, green: 0.91, blue: 0.98).opacity(0.72),
        tertiaryText: Color(red: 0.82, green: 0.88, blue: 0.96).opacity(0.50),
        chipStroke: Color.white.opacity(0.14),
        chipFill: Color.white.opacity(0.05),
        progressTrack: Color.white.opacity(0.12),
        progressFill: Color(red: 0.55, green: 0.80, blue: 0.82),
        connectorLine: Color(red: 0.72, green: 0.82, blue: 0.90).opacity(0.22)
    )

    // Light: a cool porcelain morning body. The deep tone is a desaturated slate-blue —
    // the shadow side has real weight without going grey, and the lit side is a pale
    // celadon that never clips to white against the pale background.
    static let light = MacCareStageTokens(
        isDark: false,
        bodyLit: Color(red: 0.90, green: 0.96, blue: 0.95),
        bodyMid: Color(red: 0.58, green: 0.74, blue: 0.80),
        bodyDeep: Color(red: 0.27, green: 0.42, blue: 0.55),
        bodyEdge: Color(red: 0.22, green: 0.36, blue: 0.49),
        atmosphere: Color(red: 0.55, green: 0.76, blue: 0.83),
        innerFlow: Color(red: 0.72, green: 0.88, blue: 0.90),
        rimLight: Color(red: 0.86, green: 0.95, blue: 0.97),
        orbitLine: Color(red: 0.42, green: 0.58, blue: 0.70),
        orbitPoint: Color(red: 0.30, green: 0.46, blue: 0.58),
        star: Color(red: 0.36, green: 0.52, blue: 0.66),
        normalAccent: Color(red: 0.13, green: 0.56, blue: 0.52),
        attentionAccent: Color(red: 0.66, green: 0.44, blue: 0.15),
        criticalAccent: Color(red: 0.76, green: 0.33, blue: 0.30),
        unknownAccent: Color(red: 0.40, green: 0.48, blue: 0.55),
        primaryText: Color(red: 0.075, green: 0.125, blue: 0.180),
        secondaryText: Color(red: 0.075, green: 0.125, blue: 0.180).opacity(0.66),
        tertiaryText: Color(red: 0.075, green: 0.125, blue: 0.180).opacity(0.46),
        chipStroke: Color.black.opacity(0.10),
        chipFill: Color.white.opacity(0.42),
        progressTrack: Color.black.opacity(0.10),
        progressFill: Color(red: 0.13, green: 0.56, blue: 0.52),
        connectorLine: Color(red: 0.20, green: 0.34, blue: 0.46).opacity(0.20)
    )
}

// MARK: - Resolved body material

/// The concrete body colours for one (theme, state) pair. Semantic states do not derive
/// from the healthy body by hue rotation (that produced a muddy orb in the old design);
/// each state's rim / inner-flow tint is tuned directly. The body base keeps the theme's
/// cool material and only borrows a *little* of the state accent — on the backlit rim and
/// the inner flow — so state is legible without repainting the whole sphere.
struct MacCareStageMaterial {
    let bodyLit: Color
    let bodyMid: Color
    let bodyDeep: Color
    let bodyEdge: Color
    let atmosphere: Color
    let innerFlow: Color
    let rimLight: Color
    let orbitLine: Color
    let orbitPoint: Color
    let accent: Color
    /// Relative brightness of the leading (front) orbit arc — nudged up in `critical`.
    let orbitFrontBoost: CGFloat
}

extension MacCareStageTokens {
    func material(for level: CalmSpaceHealthLevel) -> MacCareStageMaterial {
        // The state tint blended into the shadow/rim region. `attention` warms the
        // backlit rim, `critical` deepens and warms slightly, `unknown` desaturates the
        // whole body toward a calm neutral so it reads as "unknown" at a glance.
        let tintFraction: CGFloat
        let rimTint: Color
        switch level {
        case .normal:
            tintFraction = 0.0
            rimTint = rimLight
        case .attention:
            tintFraction = 0.10
            rimTint = blend(rimLight, with: accent(for: level), 0.62)
        case .critical:
            tintFraction = 0.12
            rimTint = blend(rimLight, with: accent(for: level), 0.66)
        case .unknown:
            tintFraction = 0.06
            rimTint = blend(rimLight, with: unknownAccent, 0.45)
        }

        // `unknown` is explicitly de-cooled: the lit side and inner flow are pulled hard
        // toward a neutral gray-blue so the sphere no longer reads as the teal "normal".
        if level == .unknown {
            let neutral = unknownAccent
            return MacCareStageMaterial(
                bodyLit: blend(bodyLit, with: neutral, 0.58),
                bodyMid: blend(bodyMid, with: neutral, 0.46),
                bodyDeep: blend(bodyDeep, with: neutral, 0.34),
                bodyEdge: bodyEdge,
                atmosphere: blend(atmosphere, with: neutral, 0.52),
                innerFlow: blend(innerFlow, with: neutral, 0.58),
                rimLight: rimTint,
                orbitLine: blend(orbitLine, with: neutral, 0.44),
                orbitPoint: blend(orbitPoint, with: neutral, 0.44),
                accent: neutral,
                orbitFrontBoost: 0.0
            )
        }

        return MacCareStageMaterial(
            bodyLit: bodyLit,
            bodyMid: blend(bodyMid, with: accent(for: level), tintFraction),
            bodyDeep: blend(bodyDeep, with: accent(for: level), tintFraction * 0.6),
            bodyEdge: bodyEdge,
            atmosphere: blend(atmosphere, with: accent(for: level), tintFraction),
            innerFlow: blend(innerFlow, with: accent(for: level), tintFraction),
            rimLight: rimTint,
            orbitLine: blend(orbitLine, with: accent(for: level), tintFraction * 0.8),
            orbitPoint: blend(orbitPoint, with: accent(for: level), tintFraction * 0.8),
            accent: accent(for: level),
            orbitFrontBoost: level == .critical ? 1.0 : 0.0
        )
    }

    /// Simple non-premultiplied colour blend toward `tint` by `fraction` (0...1).
    private func blend(_ base: Color, with tint: Color, _ fraction: CGFloat) -> Color {
        let f = min(max(fraction, 0), 1)
        guard f > 0 else { return base }
        let a = NSColor(base)
        let b = NSColor(tint)
        guard let mixed = a.blended(withFraction: f, of: b) else { return base }
        return Color(mixed)
    }
}

// MARK: - Breathing / motion parameters

/// Low-frequency motion parameters per state. Amplitudes are tiny (a fraction of a
/// percent) and periods are long; Reduce Motion / freeze park everything at a fixed,
/// deterministic phase so a screenshot is reproducible.
struct MacCareStageMotion {
    let breathPeriod: TimeInterval
    let breathAmplitude: CGFloat   // peak fractional scale change, e.g. 0.008 = 0.8%
    let orbitPeriod: TimeInterval

    static func motion(for level: CalmSpaceHealthLevel) -> MacCareStageMotion {
        switch level {
        case .normal:    return MacCareStageMotion(breathPeriod: 8.0, breathAmplitude: 0.008, orbitPeriod: 105)
        case .attention: return MacCareStageMotion(breathPeriod: 11.0, breathAmplitude: 0.005, orbitPeriod: 112)
        case .critical:  return MacCareStageMotion(breathPeriod: 7.0, breathAmplitude: 0.012, orbitPeriod: 96)
        case .unknown:   return MacCareStageMotion(breathPeriod: 12.0, breathAmplitude: 0.004, orbitPeriod: 120)
        }
    }
}

#endif
