import OSLog
import SwiftUI

/// Paging container for the Calm Space main window.
///
/// The two modes live side by side as complete full-window canvases (`CalmSpaceModePage`)
/// inside one clipped viewport. Switching modes slides both pages as rigid units under a
/// fixed bottom-right mode switch; a single `shellState.mode` change drives one
/// ease-in-out animation. Reduce Motion swaps the slide for a plain opacity cross-fade.
///
/// All offset/opacity/scene-activation arithmetic lives in the pure, testable
/// `CalmSpacePageTransition` model — this view only binds it to SwiftUI state.
struct CalmSpaceRootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var shellState: AppShellState

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// True while the 0.45 s mode slide/cross-fade is running. Blocks further switch
    /// requests (and the mode switch itself) so transitions can never overlap, and keeps
    /// both SpriteKit scenes rendering until the pages settle.
    @State private var isTransitioning = false

    /// Monotonic token identifying the in-flight transition. The one-shot settle task
    /// only clears the guard while its token is still current, so clearing is
    /// idempotent and an older task can never strand or clobber a newer transition.
    @State private var transitionToken = 0

    private var motionReduced: Bool {
        reduceMotion || DebugStateInjector.qaForcesReduceMotion()
    }

    private var status: CalmSpaceHealth {
        #if DEBUG
        if let forced = DebugStateInjector.qaForcedHealthLevel() {
            return CalmSpaceHealth.qaFixture(level: forced)
        }
        #endif
        return CalmSpaceHealthBuilder.make(
            snapshot: model.systemStatus,
            accessLevel: model.macCareAccessLevel
        )
    }

    var body: some View {
        mainContent
    }

    // MARK: - Prototype hook

    /// DEBUG-only isolated Stage prototype entry (`-JoeyPetQAStagePrototype`). When the
    /// flag is absent the previous, unchanged production body (`normalBody`) renders; the
    /// Release build always renders `normalBody`. No production behaviour or visual change.
    @ViewBuilder
    private var mainContent: some View {
        #if DEBUG
        if let prototype = CalmSpaceStagePrototypeQA.config {
            CalmSpaceStagePrototypeRootView(model: model, shellState: shellState, config: prototype)
        } else {
            normalBody
        }
        #else
        normalBody
        #endif
    }

    private var normalBody: some View {
        GeometryReader { proxy in
            let layout = CalmSpaceLayout(size: proxy.size)
            let palette = CalmSpacePalette.palette(for: colorScheme)
            let width = layout.size.width
            // Offsets derive from the live window width, so a resize keeps both pages
            // aligned. Reduce Motion parks both pages at offset 0 and cross-fades instead.
            let macCareOffsetX = CalmSpacePageTransition.offsetX(
                for: .macCare,
                currentMode: shellState.mode,
                width: width,
                reduceMotion: motionReduced
            )
            let workRhythmOffsetX = CalmSpacePageTransition.offsetX(
                for: .workRhythm,
                currentMode: shellState.mode,
                width: width,
                reduceMotion: motionReduced
            )
            let macCareOpacity = CalmSpacePageTransition.opacity(
                for: .macCare,
                currentMode: shellState.mode,
                reduceMotion: motionReduced
            )
            let workRhythmOpacity = CalmSpacePageTransition.opacity(
                for: .workRhythm,
                currentMode: shellState.mode,
                reduceMotion: motionReduced
            )

            ZStack(alignment: .topLeading) {
                // Viewport: both full-window pages side by side, clipped to the window.
                ZStack(alignment: .topLeading) {
                    // Z-order follows the destination mode (which flips at the start of
                    // the transition): the incoming page always sits on top, so the
                    // Reduce Motion cross-fade always fades in over an opaque page in
                    // both directions instead of showing background bleed-through.
                    page(.macCare, palette: palette, layout: layout)
                        .offset(x: macCareOffsetX)
                        .opacity(macCareOpacity)
                        .zIndex(shellState.mode == .macCare ? 1 : 0)

                    page(.workRhythm, palette: palette, layout: layout)
                        .offset(x: workRhythmOffsetX)
                        .opacity(workRhythmOpacity)
                        .zIndex(shellState.mode == .workRhythm ? 1 : 0)
                }
                .frame(width: width, height: layout.size.height, alignment: .topLeading)
                .clipped()
                .accessibilityElement(children: .contain)

                // Fixed overlay: never part of either page, so it cannot slide.
                modeSwitchOverlay(palette: palette, layout: layout)

                #if DEBUG
                if DebugStateInjector.qaShowsLayoutDebug() {
                    layoutDebugOverlay(layout: layout)
                        .position(x: width / 2, y: 22)
                }
                #endif
            }
            .frame(width: width, height: layout.size.height)
        }
        .ignoresSafeArea()
        .task {
            #if DEBUG
            await runQAHooks()
            #endif
        }
    }

    // MARK: - Pages

    private func page(
        _ mode: AppMode,
        palette: CalmSpacePalette,
        layout: CalmSpaceLayout
    ) -> some View {
        // Interactive content (the dock) is gated on "current AND settled": the mode
        // flips at the *start* of the transition, so without the settling check the
        // incoming page's dock would be clickable mid-slide.
        let isInteractive = isCurrentPage(mode) && !isTransitioning
        return CalmSpaceModePage(
            mode: mode,
            status: status,
            palette: palette,
            layout: layout,
            reduceMotion: motionReduced,
            // During the transition both scenes may render so neither page shows a
            // frozen frame; once it settles the off-screen scene is paused.
            isActive: CalmSpacePageTransition.isSceneActive(
                for: mode,
                currentMode: shellState.mode,
                isTransitioning: isTransitioning
            ),
            isCurrent: isCurrentPage(mode),
            isInteractive: isInteractive,
            onOpenDisk: { openFeature(.legacyCleanup) },
            onOpenApplications: { openFeature(.featureDetailMock) },
            onOpenSettings: { shellState.openSettings() }
        )
        .accessibilityHidden(!isCurrentPage(mode))
        .allowsHitTesting(isInteractive)
    }

    private func isCurrentPage(_ mode: AppMode) -> Bool {
        shellState.mode == mode
    }

    // MARK: - Mode switch

    private func modeSwitchOverlay(
        palette: CalmSpacePalette,
        layout: CalmSpaceLayout
    ) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            HStack(spacing: 16) {
                Spacer(minLength: 0)

                CalmSpaceModeSwitchView(
                    mode: shellState.mode,
                    palette: palette,
                    layout: layout,
                    isEnabled: !isTransitioning,
                    action: switchMode
                )
            }
            .padding(.horizontal, layout.horizontalMargin)
            .padding(.bottom, layout.bottomInset)
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .bottom)
    }

    #if DEBUG
    private func layoutDebugOverlay(layout: CalmSpaceLayout) -> some View {
        Text(String(format: "window %.0fx%.0f  orb %.0f  center %.0f,%.0f  statusTop %.0f", layout.size.width, layout.size.height, layout.orbDiameter, layout.orbCenter.x, layout.orbCenter.y, layout.statusTop))
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.7))
            .allowsHitTesting(false)
    }
    #endif

    // MARK: - Actions

    private func switchMode() {
        let source = shellState.mode
        let target = CalmSpacePageTransition.landingMode(from: source)

        // Rapid clicks: while a slide is in flight, further requests are ignored.
        guard !isTransitioning else {
            qaLog("transition ignored: \(source.rawValue) -> \(target.rawValue) (in flight)")
            return
        }
        isTransitioning = true
        transitionToken += 1
        let token = transitionToken

        withAnimation(.easeInOut(duration: CalmSpacePageTransition.duration)) {
            shellState.mode = target
            shellState.macCareRoute = .home
        }
        qaLog("transition accepted: \(source.rawValue) -> \(target.rawValue)")

        // One-shot task, not a timer: clears the guard after the slide window. An
        // external mode change mid-flight cannot strand the UI — offsets always derive
        // from `shellState.mode`, so any landing state stays consistent. The token
        // makes the clear idempotent: only the newest transition clears the guard, and
        // a torn-down view's late write is harmless.
        Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: UInt64(CalmSpacePageTransition.duration * 1_000_000_000)
            )
            guard token == transitionToken else { return }
            isTransitioning = false
            qaLog("transition settled: \(shellState.mode.rawValue)")
        }
    }

    private func openFeature(_ route: MacCareRoute) {
        shellState.mode = .macCare
        shellState.macCareRoute = route
    }

    // MARK: - DEBUG QA hooks

    #if DEBUG
    private static let qaLogger = Logger(
        subsystem: "com.zguiyang.JoeyPet",
        category: "CalmSpaceQA"
    )

    /// Logs only when `-JoeyPetQADebugRenderState` is present; silent otherwise.
    private func qaLog(_ message: String) {
        guard DebugStateInjector.qaLogsCalmSpaceRenderState() else { return }
        Self.qaLogger.info("\(message, privacy: .public)")
    }

    /// DEBUG-only launch drivers (`-JoeyPetQAAutoSwitch` / `-JoeyPetQARapidSwitch`).
    /// Runs from the single `.task` above (auto-cancelled with the view); sleeps, never
    /// a repeating timer, and drives `switchMode()` — never writes `shellState.mode`.
    private func runQAHooks() async {
        let autoInterval = DebugStateInjector.qaModeAutoSwitchInterval()
        let burstCount = DebugStateInjector.qaModeRapidSwitchBurst()
        guard autoInterval != nil || burstCount != nil else { return }

        // Let the window appear before driving switches.
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        if let burstCount {
            for _ in 0..<burstCount {
                if Task.isCancelled { return }
                switchMode()
                try? await Task.sleep(nanoseconds: 70_000_000)
            }
        }

        if let autoInterval {
            let nanoseconds = UInt64(autoInterval * 1_000_000_000)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: nanoseconds)
                if Task.isCancelled { return }
                switchMode()
            }
        }
    }
    #else
    /// Release: QA logging is compiled out entirely. The empty no-op keeps
    /// `switchMode()` free of `#if` noise while guaranteeing no log/behavior change.
    private func qaLog(_ message: String) {}
    #endif
}
