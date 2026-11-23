import AppKit
import SwiftUI

enum NestPetState: Equatable {
    case sleep
    case doze
    case wake
    case greet
    case settle
    case groom
    case awake
}

/// The pet that lives in the room's nest. It owns its own quiet day schedule
/// and never touches the desktop pet runtime. While a companionship session is
/// running it stays awake and upright instead of napping.
struct NestPetView: View {
    let isCompanioning: Bool

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var state: NestPetState = .sleep
    @State private var stateStartedAt = Date()
    @State private var twitchStartedAt: Date?
    @State private var scheduleTask: Task<Void, Never>?
    @State private var twitchTask: Task<Void, Never>?
    @State private var isWindowVisible = true

    private var theme: JoeyTheme { JoeyTheme(appearance: appearance) }

    var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 30.0,
            paused: reduceMotion || !isWindowVisible
        )) { timeline in
            Canvas { context, size in
                context.scaleBy(x: size.width / 320, y: size.height / 400)

                let elapsed = reduceMotion
                    ? 0
                    : max(0, timeline.date.timeIntervalSince(stateStartedAt))
                let twitchElapsed: TimeInterval? = {
                    guard !reduceMotion, let twitchStartedAt else { return nil }
                    let value = timeline.date.timeIntervalSince(twitchStartedAt)
                    return (0...0.3).contains(value) ? value : nil
                }()

                NestPetPainter(theme: theme).draw(
                    state: state,
                    elapsed: elapsed,
                    twitchElapsed: twitchElapsed,
                    reduceMotion: reduceMotion,
                    in: &context
                )
            }
        }
        .overlay(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .contentShape(Rectangle())
                .onTapGesture { requestGreeting() }
        }
        .background(WindowVisibilityObserver(isVisible: $isWindowVisible))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Joey")
        .accessibilityHint("点一下它会醒来跟你打招呼")
        .onAppear { syncWithSession() }
        .onDisappear { stop() }
        .onChange(of: isCompanioning) { _, _ in syncWithSession() }
        .onChange(of: reduceMotion) { _, _ in syncWithSession() }
    }

    // MARK: - Day schedule

    private enum Timing {
        static let wake: TimeInterval = 2.2
        static let greet: TimeInterval = 2.8
        static let settle: TimeInterval = 3.2
        static let groom: TimeInterval = 4.8
    }

    /// Rebuilds the running task whenever the session or Reduce Motion changes.
    /// A session always keeps Joey upright; otherwise he drifts through the day.
    private func syncWithSession() {
        stop()

        guard !reduceMotion else {
            state = isCompanioning ? .awake : .sleep
            stateStartedAt = Date()
            return
        }

        if isCompanioning {
            scheduleTask = Task { @MainActor in
                await runCompanion()
            }
        } else {
            scheduleTask = Task { @MainActor in
                if state == .awake || state == .wake || state == .greet {
                    await enter(.settle, duration: Timing.settle)
                }
                await runDay()
            }
            twitchTask = Task { @MainActor in
                await runTwitches()
            }
        }
    }

    private func stop() {
        scheduleTask?.cancel()
        scheduleTask = nil
        twitchTask?.cancel()
        twitchTask = nil
        twitchStartedAt = nil
    }

    @MainActor
    private func runCompanion() async {
        // A session wakes Joey once and greets once, then he stays upright.
        // Never run the settle step here — that would lie him back down only
        // to pop up again.
        switch state {
        case .awake:
            break
        case .greet:
            try? await Task.sleep(for: .seconds(0.6))
        case .groom:
            await enter(.greet, duration: Timing.greet)
        case .sleep, .doze, .wake, .settle:
            await enter(.wake, duration: Timing.wake)
            await enter(.greet, duration: Timing.greet)
        }
        guard !Task.isCancelled else { return }
        settleIntoAwake()
    }

    @MainActor
    private func settleIntoAwake() {
        state = .awake
        stateStartedAt = Date()
        twitchStartedAt = nil
    }

    @MainActor
    private func runDay() async {
        var cycle = 0

        while !Task.isCancelled {
            guard !isCompanioning else {
                settleIntoAwake()
                return
            }

            await enter(.sleep, duration: .random(in: 20...32))
            guard !Task.isCancelled else { return }

            if Bool.random() {
                await enter(.doze, duration: .random(in: 6...10))
                await enter(.sleep, duration: .random(in: 8...14))
            }

            cycle += 1
            if cycle % 3 == 0 {
                await wakeAndGreet()
            } else if Bool.random() {
                await enter(.groom, duration: Timing.groom)
                await enter(.sleep, duration: .random(in: 12...20))
            }
        }
    }

    @MainActor
    private func wakeAndGreet() async {
        await enter(.wake, duration: Timing.wake)
        await enter(.greet, duration: Timing.greet)
        await enter(.settle, duration: Timing.settle)
    }

    @MainActor
    private func enter(_ next: NestPetState, duration: TimeInterval) async {
        guard !Task.isCancelled else { return }
        state = next
        stateStartedAt = Date()
        if next != .sleep {
            twitchStartedAt = nil
        }
        try? await Task.sleep(for: .seconds(duration))
    }

    @MainActor
    private func runTwitches() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 40...120)))
            guard !Task.isCancelled else { return }
            guard state == .sleep else { continue }

            twitchStartedAt = Date()
            try? await Task.sleep(for: .seconds(0.3))
            twitchStartedAt = nil
        }
    }

    private func requestGreeting() {
        guard !reduceMotion else { return }
        scheduleTask?.cancel()
        twitchStartedAt = nil
        scheduleTask = Task { @MainActor in
            if state == .sleep || state == .doze {
                await wakeAndGreet()
            } else {
                await enter(.greet, duration: Timing.greet)
            }

            if isCompanioning {
                settleIntoAwake()
            } else {
                await runDay()
            }
        }
    }
}

// MARK: - Painting

private struct NestPetPainter {
    let theme: JoeyTheme

    private var art: NestPetArt { NestPetArt(theme: theme) }

    func draw(
        state: NestPetState,
        elapsed: TimeInterval,
        twitchElapsed: TimeInterval?,
        reduceMotion: Bool,
        in context: inout GraphicsContext
    ) {
        switch state {
        case .sleep:
            drawSleep(
                elapsed: elapsed,
                twitchElapsed: twitchElapsed,
                reduceMotion: reduceMotion,
                in: &context
            )
        case .doze:
            drawDoze(
                elapsed: elapsed,
                reduceMotion: reduceMotion,
                in: &context
            )
        case .wake:
            drawWake(elapsed: elapsed, in: &context)
        case .greet:
            drawGreet(elapsed: elapsed, in: &context)
        case .settle:
            drawSettle(elapsed: elapsed, in: &context)
        case .groom:
            drawGroom(elapsed: elapsed, in: &context)
        case .awake:
            drawAwake(elapsed: elapsed, in: &context)
        }
    }

    /// Upright companion pose used for the whole companionship session. It is
    /// intentionally quiet: one slow breath cycle and an occasional blink, no
    /// tail sway or other busy motion.
    private func drawAwake(elapsed: TimeInterval, in context: inout GraphicsContext) {
        let cycle = elapsed.truncatingRemainder(dividingBy: 6.5)
        let blinking = (6.28...6.46).contains(cycle)

        art.drawSitting(
            in: &context,
            face: blinking ? .blink2 : .calm,
            arms: .rest,
            breath: breath(elapsed, period: 6.5),
            tailAngle: 0
        )
    }

    private func drawSleep(
        elapsed: TimeInterval,
        twitchElapsed: TimeInterval?,
        reduceMotion: Bool,
        in context: inout GraphicsContext
    ) {
        let isTwitching = twitchElapsed.map { (0.133...0.233).contains($0) } ?? false

        art.drawLoaf(
            in: &context,
            face: .sleep,
            earTilt: 8,
            earTwitch: isTwitching,
            breath: breath(elapsed, period: 6),
            tailAngle: tailAngle(elapsed, period: 6, lag: 0.12)
        )
        art.drawZ(
            in: &context,
            elapsed: elapsed,
            count: 3,
            period: 6,
            reduceMotion: reduceMotion
        )
    }

    private func drawDoze(
        elapsed: TimeInterval,
        reduceMotion: Bool,
        in context: inout GraphicsContext
    ) {
        let cycle = elapsed.truncatingRemainder(dividingBy: 2.2)
        let nod: Double
        if cycle < 1.733 {
            nod = smoothstep(cycle / 1.733)
        } else {
            nod = 1 - smoothstep((cycle - 1.733) / 0.467)
        }

        art.drawLoaf(
            in: &context,
            face: .sleep,
            earTilt: 10,
            headOffsetY: CGFloat(1 + 3 * nod),
            breath: breath(elapsed, period: 5.4),
            tailAngle: tailAngle(elapsed, period: 5.4, lag: 0.1)
        )
        art.drawZ(
            in: &context,
            elapsed: elapsed,
            count: 2,
            period: 5.4,
            reduceMotion: reduceMotion
        )
    }

    private func drawWake(elapsed: TimeInterval, in context: inout GraphicsContext) {
        let face: NestFace
        if elapsed < 0.45 {
            face = .look
        } else if elapsed < 0.62 {
            face = .blink2
        } else if elapsed < 0.78 {
            face = .look
        } else if elapsed < 0.95 {
            face = .blink2
        } else {
            face = .look
        }

        // The body takes its time getting up: eyes open first, then a slow
        // eased rise into the sitting pose.
        let rise = smoothstep((elapsed - 1.0) / 0.95)
        let lyingOpacity = 1 - rise

        if lyingOpacity > 0.01 {
            art.drawLoaf(
                in: &context,
                face: face,
                earTilt: 2,
                breath: 1,
                tailAngle: 0,
                opacity: lyingOpacity
            )
        }

        if rise > 0.01 {
            art.drawSitting(
                in: &context,
                face: .look,
                arms: .rest,
                bodyOffset: CGSize(width: 0, height: CGFloat(12 * (1 - rise))),
                bodyScaleY: CGFloat(0.94 + 0.06 * rise),
                breath: breath(elapsed, period: 4.8),
                tailAngle: 0,
                opacity: rise
            )
        }
    }

    private func drawGreet(elapsed: TimeInterval, in context: inout GraphicsContext) {
        let face: NestFace
        if elapsed < 0.7 {
            face = .look
        } else if elapsed < 1.4 {
            face = .stretch
        } else {
            face = .happy
        }

        // Arms settle back to rest at the end so a following awake state
        // continues without a visible pop.
        let toRest = smoothstep((elapsed - 2.45) / 0.35)
        let bodyScale: CGFloat = (0.7..<1.4).contains(elapsed) ? 1.02 : 1

        let upOpacity: Double
        let waveOpacity: Double
        if elapsed < 0.7 {
            upOpacity = 0
            waveOpacity = 0
        } else if elapsed < 1.4 {
            upOpacity = 1
            waveOpacity = 0
        } else if elapsed < 1.75 {
            let progress = (elapsed - 1.4) / 0.35
            upOpacity = 1 - progress
            waveOpacity = progress
        } else {
            upOpacity = 0
            waveOpacity = 1
        }

        let waveAngle: Double
        if elapsed >= 1.9, elapsed < 2.45 {
            waveAngle = sin(2 * .pi * (elapsed - 1.9) / 0.28) * 10
        } else {
            waveAngle = 0
        }

        art.drawSitting(
            in: &context,
            face: face,
            arms: .up,
            armsOpacity: upOpacity,
            bodyScaleY: bodyScale,
            breath: breath(elapsed, period: 4.8),
            tailAngle: tailAngle(elapsed, period: 4.8, lag: 0.1)
        )

        if elapsed < 0.7 {
            art.drawSittingArms(in: &context, arms: .rest)
        } else if toRest > 0.01 {
            art.drawSittingArms(in: &context, arms: .rest, opacity: toRest)
        }
        if waveOpacity * (1 - toRest) > 0.01 {
            art.drawSittingArms(
                in: &context,
                arms: .wave,
                opacity: waveOpacity * (1 - toRest),
                waveAngle: waveAngle
            )
        }
    }

    private func drawSettle(elapsed: TimeInterval, in context: inout GraphicsContext) {
        let turn = elapsed < 1.0 ? 0 : min((elapsed - 1.0) / 0.9, 1) * 16
        let fadeOut = smoothstep((elapsed - 2.0) / 0.55)
        let fadeIn = smoothstep((elapsed - 2.45) / 0.6)
        let sittingOpacity = 1 - fadeOut

        if sittingOpacity > 0.01 {
            art.drawSitting(
                in: &context,
                face: elapsed < 1.0 ? .yawn : .calm,
                arms: .rest,
                bodyRotation: turn,
                bodyOffset: CGSize(width: 0, height: CGFloat(18 * fadeOut)),
                bodyScaleY: CGFloat(1 - 0.18 * fadeOut),
                breath: breath(elapsed, period: 4.8),
                tailAngle: tailAngle(elapsed, period: 4.8, lag: 0.1),
                opacity: sittingOpacity
            )
        }

        if fadeIn > 0.01 {
            art.drawLoaf(
                in: &context,
                face: .sleep,
                earTilt: 8,
                breath: breath(elapsed, period: 6),
                tailAngle: tailAngle(elapsed, period: 6, lag: 0.12),
                opacity: fadeIn
            )
        }
    }

    private func drawGroom(elapsed: TimeInterval, in context: inout GraphicsContext) {
        let start = smoothstep(elapsed / 0.6)
        let fadeOut = smoothstep((elapsed - 4.1) / 0.4)
        let fadeIn = smoothstep((elapsed - 4.3) / 0.45)
        let sittingOpacity = start * (1 - fadeOut)
        let lyingOpacity = max(1 - start, fadeIn * start)

        if lyingOpacity > 0.01 {
            art.drawLoaf(
                in: &context,
                face: .sleep,
                earTilt: 8,
                breath: breath(elapsed, period: 6),
                tailAngle: tailAngle(elapsed, period: 6, lag: 0.12),
                opacity: lyingOpacity
            )
        }

        if sittingOpacity > 0.01 {
            let strokeOne = groomingStroke(elapsed, start: 1.9)
            let strokeTwo = groomingStroke(elapsed, start: 3.3)
            art.drawSitting(
                in: &context,
                face: elapsed < 1.1 ? .look : .groom,
                arms: .groom,
                waveAngle: strokeOne + strokeTwo,
                bodyOffset: CGSize(width: 0, height: CGFloat(15 * fadeOut)),
                bodyScaleY: CGFloat(1 - 0.15 * fadeOut),
                breath: breath(elapsed, period: 4.8),
                tailAngle: tailAngle(elapsed, period: 4.8, lag: 0.1),
                opacity: sittingOpacity
            )
        }
    }

    private func groomingStroke(_ elapsed: TimeInterval, start: TimeInterval) -> Double {
        let local = elapsed - start
        guard (0...0.38).contains(local) else { return 0 }
        return -15 * sin(Double.pi * local / 0.38)
    }

    // MARK: - Ambient helpers

    private func breath(_ elapsed: TimeInterval, period: TimeInterval) -> CGFloat {
        let phase = elapsed.truncatingRemainder(dividingBy: period) / period
        return CGFloat(1 + 0.012 * (0.5 - 0.5 * cos(2 * .pi * phase)))
    }

    private func tailAngle(
        _ elapsed: TimeInterval,
        period: TimeInterval,
        lag: TimeInterval
    ) -> Double {
        let phase = (elapsed - lag).truncatingRemainder(dividingBy: period) / period
        return 8 * sin(2 * .pi * phase)
    }

    private func smoothstep(_ value: Double) -> Double {
        let t = clamp(value)
        return t * t * (3 - 2 * t)
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

// MARK: - Window visibility

private struct WindowVisibilityObserver: NSViewRepresentable {
    @Binding var isVisible: Bool

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onWindowChanged = { window in
            context.coordinator.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isVisible: $isVisible)
    }

    final class ObserverView: NSView {
        var onWindowChanged: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChanged?(window)
        }
    }

    final class Coordinator {
        private let isVisible: Binding<Bool>
        private weak var window: NSWindow?
        private var tokens: [NSObjectProtocol] = []

        init(isVisible: Binding<Bool>) {
            self.isVisible = isVisible
        }

        func attach(to window: NSWindow?) {
            guard self.window !== window else { return }
            self.window = window

            for token in tokens {
                NotificationCenter.default.removeObserver(token)
            }
            tokens.removeAll()

            guard let window else {
                isVisible.wrappedValue = false
                return
            }

            let update = { [weak self, weak window] in
                guard let self, let window else { return }
                self.isVisible.wrappedValue = window.occlusionState.contains(.visible)
                    && !window.isMiniaturized
                    && !NSApp.isHidden
            }
            update()

            let center = NotificationCenter.default
            tokens.append(center.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window,
                queue: .main
            ) { _ in update() })
            tokens.append(center.addObserver(
                forName: NSWindow.didMiniaturizeNotification,
                object: window,
                queue: .main
            ) { _ in update() })
            tokens.append(center.addObserver(
                forName: NSWindow.didDeminiaturizeNotification,
                object: window,
                queue: .main
            ) { _ in update() })
            tokens.append(center.addObserver(
                forName: NSApplication.didHideNotification,
                object: nil,
                queue: .main
            ) { _ in update() })
            tokens.append(center.addObserver(
                forName: NSApplication.didUnhideNotification,
                object: nil,
                queue: .main
            ) { _ in update() })
        }

        deinit {
            for token in tokens {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }
}
