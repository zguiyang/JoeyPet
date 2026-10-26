import AppKit
import SwiftUI

#if DEBUG
/// The isolated, DEBUG-only Stage prototype page.
///
/// It stands in for the whole Calm Space main window so a Stage design can be validated
/// in isolation, at the real window geometry, with the production bottom dock and mode
/// switch reused verbatim. Entered only via `-JoeyPetQAStagePrototype`; not reachable
/// from any production path. All content is MOCK (`StagePrototypeFixtures`) and the page
/// is permanently marked "原型预览 · 模拟数据".
struct CalmSpaceStagePrototypeRootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var shellState: AppShellState
    let config: CalmSpaceStagePrototypeQA

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var frozen: Bool { config.isFrozen(reduceMotion: reduceMotion) }

    var body: some View {
        GeometryReader { proxy in
            let layout = CalmSpaceStageLayout(size: proxy.size)
            let wrLayout = WorkRhythmStageLayout(size: proxy.size)
            let palette = CalmSpacePalette.palette(for: colorScheme)
            let tokens = MacCareStageTokens.tokens(for: colorScheme)
            let wrTheme = WorkRhythmStageTheme.theme(for: colorScheme)

            ZStack(alignment: .topLeading) {
                background(palette: palette, size: layout.size, warm: config.mode == .workRhythm)
                starField(tokens: tokens, size: layout.size)

                stage(layout: layout, wrLayout: wrLayout, tokens: tokens, wrTheme: wrTheme)

                bottomBar(palette: palette, layout: layout)
                badge(tokens: tokens, layout: layout)
            }
            .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .task { await snapshotWindowIfRequested() }
    }

    // MARK: - Offscreen snapshot (QA capture on a locked display)

    /// When `-JoeyPetQASnapshotOut <path.png>` is present, render this window offscreen to
    /// a PNG and exit. This renders the app's own live window (no Screen Recording / TCC
    /// needed) — real prototype pixels, not a concept render. Used because the capture
    /// display may be locked. No-op on the normal QA path.
    @MainActor
    private func snapshotWindowIfRequested() async {
        guard let path = DebugStateInjector.qaSnapshotOutputPath() else { return }
        // Let the window appear, lay out and render its first frame.
        try? await Task.sleep(nanoseconds: 1_400_000_000)

        let candidate = NSApp.windows
            .filter { $0.contentView != nil && $0.frame.width > 1 && $0.frame.height > 1 }
            .max { ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height) }
        guard let win = candidate else { return }

        win.contentView?.layoutSubtreeIfNeeded()
        win.displayIfNeeded()

        // Prefer the whole window (theme frame, includes traffic lights); fall back to the
        // content view if the superview cannot be rendered.
        let target = win.contentView?.superview ?? win.contentView
        guard let view = target,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.layoutSubtreeIfNeeded()
        view.cacheDisplay(in: view.bounds, to: rep)

        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
        NSApp.terminate(nil)
    }

    // MARK: - Stage

    @ViewBuilder
    private func stage(
        layout: CalmSpaceStageLayout,
        wrLayout: WorkRhythmStageLayout,
        tokens: MacCareStageTokens,
        wrTheme: WorkRhythmStageTheme
    ) -> some View {
        if config.mode == .workRhythm {
            WorkRhythmStageView(
                theme: wrTheme,
                layout: wrLayout,
                content: WorkRhythmStageFixtures.content(state: config.state, longCopy: config.longCopy),
                reduceMotion: reduceMotion,
                freeze: config.freeze
            )
        } else {
            let content = StagePrototypeFixtures.macCareContent(
                state: config.state,
                activityOverride: config.activity,
                longCopy: config.longCopy
            )
            MacCareStageView(
                tokens: tokens,
                material: tokens.material(for: content.level),
                layout: layout,
                content: content,
                variant: config.variant,
                reduceMotion: reduceMotion,
                freeze: config.freeze,
                onAction: {}
            )
        }
    }

    // MARK: - Background
    //
    // Reuses the existing Calm Space full-window gradient family (same palette roles and
    // stacking as `CalmSpaceModePage`) so the prototype reads as the same product, not a
    // new style.

    private func background(palette: CalmSpacePalette, size: CGSize, warm: Bool = false) -> some View {
        let diameter = max(size.width, size.height)
        return ZStack {
            LinearGradient(
                colors: [palette.backgroundTop, palette.backgroundMid, palette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [palette.ambientSecondary.opacity(palette.isDark ? 0.16 : 0.28), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: diameter * 0.82
            )
            RadialGradient(
                colors: [palette.ambientPrimary.opacity(palette.isDark ? 0.10 : 0.18), .clear],
                center: UnitPoint(x: 0.18, y: 0.86),
                startRadius: 0,
                endRadius: diameter * 0.72
            )
            LinearGradient(
                colors: [palette.ambientPrimary.opacity(palette.isDark ? 0.06 : 0.07), .clear],
                startPoint: .bottomLeading,
                endPoint: .center
            )
            // Work Rhythm leans a touch warmer/deeper than Mac Care, staying inside the
            // same Calm Space gradient family — a tint, never a second visual language.
            if warm {
                LinearGradient(
                    colors: [
                        (palette.isDark ? Color(red: 0.36, green: 0.28, blue: 0.20) : Color(red: 0.86, green: 0.80, blue: 0.66))
                            .opacity(palette.isDark ? 0.10 : 0.08),
                        .clear,
                    ],
                    startPoint: .bottom,
                    endPoint: .center
                )
            }
            RadialGradient(
                colors: [.clear, palette.backgroundBottom.opacity(palette.isDark ? 0.55 : 0.22)],
                center: .center,
                startRadius: diameter * 0.18,
                endRadius: diameter * 0.76
            )
        }
    }

    /// ≤ 6 static micro-stars. Slow 60 s+ shimmer only when motion is allowed.
    private func starField(tokens: MacCareStageTokens, size: CGSize) -> some View {
        ZStack {
            ForEach(Array(StagePrototypeFixtures.stars.enumerated()), id: \.offset) { _, p in
                Circle()
                    .fill(tokens.star.opacity(tokens.isDark ? 0.5 : 0.35))
                    .frame(width: 1.6, height: 1.6)
                    .position(x: p.x * size.width, y: p.y * size.height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Bottom controls (production reuse)

    /// Bottom-left dock + bottom-right mode switch at exactly their production insets.
    /// The mode switch is disabled: Unit 1 is Mac Care only and there is no Work Rhythm
    /// page to slide to, but its resting position/visual must still be verified.
    private func bottomBar(palette: CalmSpacePalette, layout: CalmSpaceStageLayout) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 16) {
                if config.mode == .workRhythm {
                    workRhythmDock(palette: palette, layout: layout.base)
                } else {
                    CalmSpaceDockView(
                        palette: palette,
                        layout: layout.base,
                        mode: .macCare,
                        onOpenDisk: {},
                        onOpenApplications: {},
                        onOpenSettings: {}
                    )
                }

                Spacer(minLength: 0)

                CalmSpaceModeSwitchView(
                    mode: config.mode == .workRhythm ? .workRhythm : .macCare,
                    palette: palette,
                    layout: layout.base,
                    isEnabled: false,
                    action: {}
                )
            }
            .padding(.horizontal, layout.base.horizontalMargin)
            .padding(.bottom, layout.base.bottomInset)
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .bottom)
        .accessibilityHidden(true)
    }

    /// Work Rhythm prototype dock: a disabled "统计" entry (a future feature) plus a live
    /// "系统设置". Deliberately avoids duplicating the Stage's own start/pause controls.
    /// Prototype-local (does not touch production `CalmSpaceDockView`); Unit 2 notes flag
    /// this as the intended future direction.
    private func workRhythmDock(palette: CalmSpacePalette, layout: CalmSpaceLayout) -> some View {
        HStack(spacing: layout.compact ? 8 : 10) {
            wrDockPill(title: "统计", systemImage: "chart.bar", enabled: false, palette: palette, layout: layout)
            wrDockPill(title: "系统设置", systemImage: "gearshape", enabled: true, palette: palette, layout: layout)
        }
    }

    private func wrDockPill(
        title: String,
        systemImage: String,
        enabled: Bool,
        palette: CalmSpacePalette,
        layout: CalmSpaceLayout
    ) -> some View {
        let labelColor = enabled ? palette.secondaryText : palette.tertiaryText
        let shape = RoundedRectangle(cornerRadius: layout.compact ? 10 : layout.dockHeight / 2, style: .continuous)
        return HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(labelColor)
                .accessibilityHidden(true)
            if !layout.compact {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, layout.compact ? 0 : 11)
        .frame(width: layout.compact ? layout.dockHeight : nil, height: layout.dockHeight)
        .background(shape.fill(palette.controlFill))
        .overlay(shape.strokeBorder(palette.controlStroke, lineWidth: 1))
        .accessibilityLabel(Text(enabled ? title : "\(title)，尚未开放"))
    }

    // MARK: - Prototype badge

    /// A deliberately quiet top-trailing marker. Never a pill, never a warning colour.
    private func badge(tokens: MacCareStageTokens, layout: CalmSpaceStageLayout) -> some View {
        VStack {
            HStack {
                Spacer(minLength: 0)
                Text("原型预览 · 模拟数据")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(tokens.tertiaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.trailing, layout.badgeTrailing)
        .padding(.top, layout.badgeTop)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
