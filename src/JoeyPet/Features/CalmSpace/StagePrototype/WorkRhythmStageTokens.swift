import SwiftUI

#if DEBUG

// MARK: - Work Rhythm Stage tokens
//
// Semantic colours for the Work Rhythm "time instrument" Stage, tuned independently per
// theme. Focus is a cool misty indigo (quiet concentration), Rest a low-saturation warm
// sand/sage (unmistakably different from Focus and from every Mac Care semantic colour).
// The dark theme is deep ink-navy with ivory digits; the light theme is a matte paper with
// ink digits — not an inversion. No neon anywhere. Every colour lives here.
struct WorkRhythmStageTheme {
    let isDark: Bool

    // Phase accents (arc + label).
    let focusAccent: Color
    let focusHead: Color      // brighter leading edge of the focus arc
    let restAccent: Color
    let restHead: Color
    let idleAccent: Color     // neutral cool — the travelling second dot
    let pausedAccent: Color   // neutral — paused arc / label

    // Device chrome.
    let track: Color          // low-contrast neutral progress track
    let bezel: Color          // hairline bezel + tick marks
    let timeText: Color       // central digits (ivory / ink)
    let phaseLabel: Color
    let secondaryText: Color

    // Controls.
    let ghostStroke: Color
    let ghostFill: Color
    let primaryStroke: Color

    static func theme(for colorScheme: ColorScheme) -> WorkRhythmStageTheme {
        colorScheme == .dark ? .dark : .light
    }

    func accent(for phase: WorkRhythmPhase) -> Color {
        switch phase {
        case .idle: return idleAccent
        case .focus: return focusAccent
        case .paused: return pausedAccent
        case .rest: return restAccent
        case .complete: return focusAccent
        }
    }

    /// Brighter leading-edge colour for the arc head of a phase.
    func head(for phase: WorkRhythmPhase) -> Color {
        switch phase {
        case .rest: return restHead
        default: return focusHead
        }
    }
}

extension WorkRhythmStageTheme {
    // Dark: deep ink-navy field, misty indigo focus, warm sand rest, ivory digits.
    static let dark = WorkRhythmStageTheme(
        isDark: true,
        focusAccent: Color(red: 0.56, green: 0.66, blue: 0.92),
        focusHead: Color(red: 0.76, green: 0.83, blue: 0.99),
        restAccent: Color(red: 0.85, green: 0.76, blue: 0.55),
        restHead: Color(red: 0.95, green: 0.89, blue: 0.71),
        idleAccent: Color(red: 0.60, green: 0.72, blue: 0.82),
        pausedAccent: Color(red: 0.66, green: 0.72, blue: 0.82),
        track: Color.white.opacity(0.10),
        bezel: Color(red: 0.74, green: 0.83, blue: 0.93),   // full alpha; drawn alphas set in the view
        timeText: Color(red: 0.96, green: 0.95, blue: 0.92),
        phaseLabel: Color(red: 0.90, green: 0.93, blue: 0.98),
        secondaryText: Color(red: 0.82, green: 0.88, blue: 0.96).opacity(0.52),
        ghostStroke: Color.white.opacity(0.14),
        ghostFill: Color.white.opacity(0.05),
        primaryStroke: Color.white.opacity(0.16)
    )

    // Light: matte paper. Indigo / sand read as ink on paper; digits are near-black for
    // maximum contrast. Independently tuned, never an inverted dark.
    static let light = WorkRhythmStageTheme(
        isDark: false,
        focusAccent: Color(red: 0.28, green: 0.38, blue: 0.64),
        focusHead: Color(red: 0.20, green: 0.30, blue: 0.56),
        restAccent: Color(red: 0.56, green: 0.47, blue: 0.28),
        restHead: Color(red: 0.46, green: 0.39, blue: 0.22),
        idleAccent: Color(red: 0.34, green: 0.44, blue: 0.58),
        pausedAccent: Color(red: 0.42, green: 0.48, blue: 0.56),
        track: Color.black.opacity(0.10),
        bezel: Color(red: 0.20, green: 0.34, blue: 0.46),   // full alpha; drawn alphas set in the view
        timeText: Color(red: 0.10, green: 0.14, blue: 0.20),
        phaseLabel: Color(red: 0.12, green: 0.16, blue: 0.22),
        secondaryText: Color(red: 0.10, green: 0.14, blue: 0.20).opacity(0.55),
        ghostStroke: Color.black.opacity(0.12),
        ghostFill: Color.white.opacity(0.42),
        primaryStroke: Color.black.opacity(0.10)
    )
}

#endif
