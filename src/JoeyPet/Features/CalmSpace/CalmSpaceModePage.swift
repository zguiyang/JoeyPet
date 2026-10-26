import SwiftUI

/// One complete full-window Calm Space canvas for a single mode.
///
/// Everything a mode shows lives inside this page — background ambience, the central
/// animation, the status block and the bottom dock — so `CalmSpaceRootView` can lay the
/// two pages side by side and slide them as rigid units. Only the fixed mode switch is
/// drawn outside, in the root overlay.
struct CalmSpaceModePage: View {
    let mode: AppMode
    let status: CalmSpaceHealth
    let palette: CalmSpacePalette
    let layout: CalmSpaceLayout
    let reduceMotion: Bool
    /// `true` while this page's SpriteKit layer may render. The root keeps it `true`
    /// during a slide/cross-fade and pauses the off-screen page once it settles.
    let isActive: Bool
    /// `true` when this page is the visible/current mode. Gates accessibility; the
    /// root hides the inactive page entirely.
    let isCurrent: Bool
    /// `true` only when this page is current *and* no transition is in flight. Gates
    /// hit testing on interactive children (the dock), so the incoming page's dock can
    /// never be clicked mid-slide — the mode flips at the *start* of the transition.
    let isInteractive: Bool
    let onOpenDisk: () -> Void
    let onOpenApplications: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            background

            centralAnimation
                .frame(width: layout.size.width, height: layout.size.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            statusBlock

            bottomBar
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
    }

    // MARK: - Central animation

    @ViewBuilder
    private var centralAnimation: some View {
        switch mode {
        case .macCare:
            CalmSpaceOrbView(style: orbStyle, isActive: isActive)
        case .workRhythm:
            CalmSpaceRhythmView(style: rhythmStyle, isActive: isActive)
        }
    }

    private var orbStyle: CalmSpaceOrbStyle {
        CalmSpaceOrbStyle(
            isDark: palette.isDark,
            health: status.level,
            mode: mode,
            reduceMotion: reduceMotion,
            orbDiameter: layout.orbDiameter,
            orbCenter: layout.orbCenter
        )
    }

    /// Work Rhythm's dial occupies exactly the orb's reserved central slot
    /// (`layout.orbDiameter` / `layout.orbCenter`), so status copy and dock never move.
    /// Phase is fixed to `.idle` and progress stays `nil` until a real session exists.
    private var rhythmStyle: CalmSpaceRhythmStyle {
        CalmSpaceRhythmStyle(
            phase: .idle,
            progress: nil,
            isDark: palette.isDark,
            reduceMotion: reduceMotion,
            dialDiameter: layout.orbDiameter,
            dialCenter: layout.orbCenter
        )
    }

    // MARK: - Background

    private var background: some View {
        let diameter = max(layout.size.width, layout.size.height)
        return ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundMid, palette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    palette.ambientSecondary.opacity(palette.isDark ? 0.16 : 0.28),
                    .clear,
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: diameter * 0.82
            )

            RadialGradient(
                colors: [
                    palette.ambientPrimary.opacity(palette.isDark ? 0.10 : 0.18),
                    .clear,
                ],
                center: UnitPoint(x: 0.18, y: 0.86),
                startRadius: 0,
                endRadius: diameter * 0.72
            )

            modeTint

            RadialGradient(
                colors: [
                    .clear,
                    palette.backgroundBottom.opacity(palette.isDark ? 0.55 : 0.22),
                ],
                center: .center,
                startRadius: diameter * 0.18,
                endRadius: diameter * 0.76
            )
        }
    }

    private var modeTint: some View {
        ZStack {
            LinearGradient(
                colors: [
                    palette.ambientSecondary.opacity(palette.isDark ? 0.10 : 0.08),
                    .clear,
                ],
                startPoint: .topTrailing,
                endPoint: .center
            )
            .opacity(mode == .workRhythm ? 1 : 0)

            LinearGradient(
                colors: [
                    palette.ambientPrimary.opacity(palette.isDark ? 0.06 : 0.07),
                    .clear,
                ],
                startPoint: .bottomLeading,
                endPoint: .center
            )
            .opacity(mode == .macCare ? 1 : 0)
        }
    }

    // MARK: - Status

    private var statusBlock: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: layout.statusTop)

            ZStack(alignment: .top) {
                if mode == .macCare {
                    CalmSpaceStatusView(status: status, palette: palette, layout: layout)
                } else {
                    CalmSpaceWorkRhythmStatusView(
                        palette: palette,
                        layout: layout,
                        hasRealHealthData: status.level != .unknown
                    )
                }
            }
            .frame(width: layout.size.width, height: layout.statusReservedHeight, alignment: .top)
            .clipped()

            Spacer(minLength: 0)
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .top)
        .allowsHitTesting(false)
    }

    // MARK: - Bottom bar

    /// The mode dock, owned by the page so it slides with the canvas, followed by a
    /// transparent reservation for the fixed mode switch. The dock can therefore never
    /// slide underneath the switch.
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 12) {
                CalmSpaceDockView(
                    palette: palette,
                    layout: layout,
                    mode: mode,
                    onOpenDisk: onOpenDisk,
                    onOpenApplications: onOpenApplications,
                    onOpenSettings: onOpenSettings
                )

                Spacer(minLength: 0)

                Color.clear
                    .frame(width: layout.modeSwitchExpandedWidth)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, layout.horizontalMargin)
            .padding(.bottom, layout.bottomInset)
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .bottom)
        .allowsHitTesting(isInteractive)
        .accessibilityHidden(!isCurrent)
    }
}
