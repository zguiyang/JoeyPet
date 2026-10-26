import SwiftUI

#if DEBUG

// MARK: - Work Rhythm Stage
//
// A "time instrument": a fixed bezel with 60 fine ticks, a neutral progress track, a
// clockwise progress arc from 12 o'clock with a soft head marker, and the countdown in the
// optical centre. It reads as *计时 / 专注* — not a radar, a system monitor, or a dial with
// a spinning light. Idle shows the real local time with a single second dot travelling the
// bezel; no false progress. Everything derives from the window size via
// `WorkRhythmStageLayout`; nothing is a whole-view scale.
//
// Motion is low-frequency: the countdown ticks at 1 Hz from an absolute remaining value
// (a real implementation derives from a deadline so frame rate never affects accuracy),
// the head glow breathes on a slow implicit animation, and Reduce Motion / freeze park
// every loop at a deterministic phase.
struct WorkRhythmStageView: View {
    let theme: WorkRhythmStageTheme
    let layout: WorkRhythmStageLayout
    let content: WorkRhythmStageContent
    let reduceMotion: Bool
    let freeze: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var frozen: Bool { reduceMotion || freeze }
    private var accent: Color { theme.accent(for: content.phase) }
    private var head: Color { theme.head(for: content.phase) }

    /// MOCK countdown seed. `nil` when no timer runs (idle).
    @State private var remaining: TimeInterval?
    @State private var startDate = Date()
    @State private var glowBright = false
    @State private var idleBreath = false

    init(
        theme: WorkRhythmStageTheme,
        layout: WorkRhythmStageLayout,
        content: WorkRhythmStageContent,
        reduceMotion: Bool,
        freeze: Bool
    ) {
        self.theme = theme
        self.layout = layout
        self.content = content
        self.reduceMotion = reduceMotion
        self.freeze = freeze
        self._remaining = State(initialValue: content.remainingSeconds)
    }

    private var isTicking: Bool {
        !frozen && (content.phase == .focus || content.phase == .rest)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            device
            actionRow
            if let stat = content.todayStat, !layout.compact { todayStat(stat) }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .onAppear {
            startDate = Date()
            guard !frozen else { return }
            if content.phase == .focus || content.phase == .rest {
                withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                    glowBright = true
                }
            }
            if content.phase == .idle {
                withAnimation(.easeInOut(duration: 10.0).repeatForever(autoreverses: true)) {
                    idleBreath = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.6), value: content.phase)
    }

    // MARK: - Device

    private var device: some View {
        ZStack {
            if isTicking {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    deviceStack(remaining: ticked(context.date))
                }
            } else {
                deviceStack(remaining: remaining)
            }
        }
        .position(x: layout.deviceCenter.x, y: layout.deviceCenter.y)
    }

    private func deviceStack(remaining: TimeInterval?) -> some View {
        let progress = progressValue(remaining)
        return ZStack {
            // Static chrome + arc + markers.
            Canvas { context, size in
                drawChrome(context: context, size: size, progress: progress)
            }
            .frame(width: layout.deviceDiameter, height: layout.deviceDiameter)
            .opacity(content.phase == .idle && !frozen ? (idleBreath ? 0.95 : 1.0) : 1.0)

            // Head glow (breathing when running; absent when paused / complete).
            if content.showsProgressArc, progress > 0.002, !content.isPaused, content.phase != .complete {
                headGlow(progress: progress)
            }

            // One-shot completion bloom (static in freeze).
            if content.phase == .complete {
                completeHalo
            }

            centerText(remaining: remaining)
                .frame(width: layout.deviceDiameter, height: layout.deviceDiameter)
        }
        .frame(width: layout.deviceDiameter, height: layout.deviceDiameter)
    }

    // MARK: - Chrome drawing (Canvas)

    private func drawChrome(context: GraphicsContext, size: CGSize, progress: Double) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let bezelR = layout.bezelRadius
        let trackR = layout.trackRadius

        // Bezel hairline (never rotates).
        let bezel = Path(ellipseIn: CGRect(x: c.x - bezelR, y: c.y - bezelR, width: bezelR * 2, height: bezelR * 2))
        context.stroke(bezel, with: .color(theme.bezel.opacity(0.13)), style: StrokeStyle(lineWidth: 0.7))

        // 60 fine ticks; 12/3/6/9 longer and brighter — a refined dial, legible at 1:1.
        for i in 0..<60 {
            let cardinal = i % 15 == 0
            let angle = (-90.0 + Double(i) * 6.0) * .pi / 180
            let len: CGFloat = cardinal ? 3.75 : 2.0
            let op: CGFloat = cardinal ? 0.55 : 0.33
            let outer = point(on: bezelR, angle: angle, center: c)
            let inner = point(on: bezelR - len, angle: angle, center: c)
            var tick = Path()
            tick.move(to: outer)
            tick.addLine(to: inner)
            context.stroke(tick, with: .color(theme.bezel.opacity(op)),
                           style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        }

        // Idle: a single second dot travels the bezel; no progress arc at all.
        if content.showSecondDot {
            let sec = secondOfDay()
            let angle = (-90.0 + (sec / 60.0) * 360.0) * .pi / 180
            let p = point(on: bezelR, angle: angle, center: c)
            let dot = CGRect(x: p.x - 1.0, y: p.y - 1.0, width: 2.0, height: 2.0)
            context.fill(Path(ellipseIn: dot), with: .color(theme.idleAccent))
        }

        guard content.showsProgressArc else { return }

        // Neutral progress track.
        let track = Path(ellipseIn: CGRect(x: c.x - trackR, y: c.y - trackR, width: trackR * 2, height: trackR * 2))
        context.stroke(track, with: .color(theme.track), style: StrokeStyle(lineWidth: 2.2))

        // Progress arc: from 12 o'clock, clockwise; one continuous stroked path with a
        // conic gradient so the head reads brighter than the tail (no segment beading).
        guard progress > 0.001 else { return }
        let arcWidth: CGFloat = content.phase == .rest ? 2.4 : 2.8
        let startA = -90.0
        let endA = -90.0 + progress * 360.0
        let steps = max(48, Int(progress * 200))
        var arcPath = Path()
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let a = (startA + (endA - startA) * t) * .pi / 180
            let p = point(on: trackR, angle: a, center: c)
            if i == 0 { arcPath.move(to: p) } else { arcPath.addLine(to: p) }
        }
        let dim: CGFloat = content.isPaused ? 0.7 : 1.0
        let headStop = max(0.001, min(progress, 0.999))
        let arcGradient = Gradient(stops: [
            .init(color: accent.opacity(0.50 * dim), location: 0),
            .init(color: accent.opacity(0.97 * dim), location: headStop),
            .init(color: accent.opacity(0.97 * dim), location: 1),
        ])
        context.stroke(
            arcPath,
            with: .conicGradient(arcGradient, center: c, angle: .degrees(-90)),
            style: StrokeStyle(lineWidth: arcWidth, lineCap: .round)
        )

        // Head marker: a dot when running, two small bars (no glow) when paused.
        let headAngle = endA * .pi / 180
        let hp = point(on: trackR, angle: headAngle, center: c)
        if content.isPaused {
            let barColor = accent.opacity(0.8)
            let offsets: [CGFloat] = [-2.2, 2.2]
            for dx in offsets {
                let top = CGPoint(x: hp.x + dx, y: hp.y - 3)
                let bot = CGPoint(x: hp.x + dx, y: hp.y + 3)
                var bar = Path()
                bar.move(to: top)
                bar.addLine(to: bot)
                context.stroke(bar, with: .color(barColor), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        } else {
            let dot = CGRect(x: hp.x - 1.5, y: hp.y - 1.5, width: 3.0, height: 3.0)
            context.fill(Path(ellipseIn: dot), with: .color(head))
        }
    }

    /// A soft ≤8 pt glow at the arc head; breathes only while running.
    private func headGlow(progress: Double) -> some View {
        let angle = (-90.0 + progress * 360.0) * .pi / 180
        let hp = point(on: layout.trackRadius, angle: angle,
                       center: CGPoint(x: layout.deviceDiameter / 2, y: layout.deviceDiameter / 2))
        let base: CGFloat = theme.isDark ? 0.26 : 0.22
        let o = frozen ? base : (glowBright ? base : base * 0.55)
        return Circle()
            .fill(head.opacity(o))
            .frame(width: 8, height: 8)
            .blur(radius: 4)
            .position(x: hp.x, y: hp.y)
            .allowsHitTesting(false)
    }

    /// One soft, non-looping completion bloom around the closed arc — a gentle exhale,
    /// not a neon HUD ring.
    private var completeHalo: some View {
        Circle()
            .stroke(head.opacity(theme.isDark ? 0.13 : 0.10), lineWidth: 6)
            .frame(width: layout.trackRadius * 2, height: layout.trackRadius * 2)
            .blur(radius: 10)
            .allowsHitTesting(false)
    }

    // MARK: - Centre text

    private func centerText(remaining: TimeInterval?) -> some View {
        let isWords = content.wordsText != nil
        let timeSize = isWords ? layout.timeFontSize * 0.5 : layout.timeFontSize
        return VStack(spacing: layout.compact ? 7 : 9) {
            Text(content.centerText)
                .font(.system(size: timeSize, weight: .medium))
                .tracking(0.5)
                .monospacedDigit()
                .foregroundStyle(theme.timeText.opacity(content.isPaused ? 0.72 : 1.0))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let label = content.phaseLabel {
                HStack(spacing: 6) {
                    if content.showPhaseDot {
                        Circle().fill(accent).frame(width: 5, height: 5)
                            .accessibilityHidden(true)
                    }
                    Text(label)
                        .font(.system(size: layout.phaseLabelSize, weight: .medium))
                        .foregroundStyle(content.phase == .idle ? theme.phaseLabel : accent)
                }
            }

            if let sec = content.secondary {
                Text(sec)
                    .font(.system(size: layout.secondarySize))
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: layout.deviceDiameter * 0.66)
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: layout.compact ? 12 : 16) {
            if let primary = content.primary { actionButton(primary) }
            if let secondary = content.secondaryAction { actionButton(secondary) }
        }
        .position(x: layout.size.width / 2, y: layout.actionRowTop + layout.actionRowHeight / 2)
    }

    @ViewBuilder
    private func actionButton(_ action: WorkRhythmAction) -> some View {
        switch action.kind {
        case .primary: primaryPill(action.title)
        case .ghost: ghostPill(action.title)
        case .text:
            Text(action.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .padding(.horizontal, 4)
                .frame(height: layout.actionRowHeight)
        }
    }

    /// Restrained focus-accent entry (start / resume / again) — the primary action always
    /// carries the focus accent so it stands out from the neutral ghost controls.
    private func primaryPill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.focusAccent)
            .padding(.horizontal, 20)
            .frame(height: layout.actionRowHeight)
            .background(Capsule(style: .continuous).fill(theme.focusAccent.opacity(theme.isDark ? 0.13 : 0.11)))
            .overlay(Capsule(style: .continuous).strokeBorder(theme.focusAccent.opacity(0.42), lineWidth: 1))
    }

    private func ghostPill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(theme.isDark ? Color.white.opacity(0.86) : theme.timeText)
            .padding(.horizontal, 18)
            .frame(height: layout.actionRowHeight)
            .background(Capsule(style: .continuous).fill(theme.ghostFill))
            .overlay(Capsule(style: .continuous).strokeBorder(theme.ghostStroke, lineWidth: 1))
    }

    // MARK: - Periphery stat

    private func todayStat(_ stat: String) -> some View {
        Text(stat)
            .font(.system(size: 11))
            .foregroundStyle(theme.secondaryText)
            .frame(width: 260, alignment: .trailing)
            .position(x: layout.size.width - layout.base.horizontalMargin - 130,
                      y: layout.base.bottomControlsTop - 15)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private func progressValue(_ remaining: TimeInterval?) -> Double {
        guard let remaining, content.totalSeconds > 0 else {
            return content.phase == .complete ? 1 : 0
        }
        return min(max((content.totalSeconds - remaining) / content.totalSeconds, 0), 1)
    }

    /// MOCK countdown tick from an absolute start, so a dropped frame never shifts time.
    private func ticked(_ date: Date) -> TimeInterval? {
        guard let base = content.remainingSeconds else { return nil }
        let elapsed = max(0, date.timeIntervalSince(startDate))
        return max(0, base - elapsed)
    }

    /// Whole-second phase of the current minute for the idle second dot.
    private func secondOfDay() -> CGFloat {
        let s = Calendar.current.component(.second, from: Date())
        return CGFloat(frozen ? 12 : s)   // frozen: a fixed, reproducible position
    }

    private func point(on radius: CGFloat, angle: Double, center: CGPoint) -> CGPoint {
        CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
    }
}

#endif
