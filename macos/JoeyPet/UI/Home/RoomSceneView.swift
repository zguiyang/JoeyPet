import AppKit
import SwiftUI

struct RoomSceneView: View {
    let rhythmMinutes: Int
    let status: CompanionStatus
    let onOpenReflection: () -> Void
    let onOpenClockSettings: () -> Void
    let onPrimaryAction: () -> Void
    let onGreetPet: () -> Void
    var onInviteAccept: (() -> Void)?
    var onInviteSnooze: (() -> Void)?
    var onInviteDoNotDisturb: (() -> Void)?

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.joeyChromeTone) private var chromeTone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFrameHovering = false
    @State private var isClockHovering = false

    private let designSize = CGSize(width: 1080, height: 680)
    /// Floor CTA sits on the scene midline (DESIGN §10.4), not under the desk.
    private let floorCenterX: CGFloat = 540
    /// Chrome / labels follow Settings appearance; the room canvas uses daypart.
    private var chromeTheme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 60 : 1 / 12)) { timeline in
            let daypart = appearance.resolveRoomDaypart(at: timeline.date)
            let theme = JoeyTheme(chromeTone: chromeTone, daypart: daypart)
            let curtainPhase = reduceMotion
                ? 0
                : sin(timeline.date.timeIntervalSinceReferenceDate / 5.5) * 3.2

            GeometryReader { geometry in
                let scale = min(
                    geometry.size.width / designSize.width,
                    geometry.size.height / designSize.height
                )
                let sceneWidth = designSize.width * scale
                let sceneHeight = designSize.height * scale
                let originX = (geometry.size.width - sceneWidth) / 2
                let originY = (geometry.size.height - sceneHeight) / 2

                ZStack(alignment: .topLeading) {
                    theme.roomWall

                    Canvas { context, _ in
                        var painterContext = context
                        painterContext.translateBy(x: originX, y: originY)
                        painterContext.scaleBy(x: scale, y: scale)
                        RoomPainter(theme: theme, curtainPhase: curtainPhase)
                            .draw(in: &painterContext)
                    }

                    RoomClockHandsView(theme: theme)
                        .frame(width: 88 * scale, height: 88 * scale)
                        .position(
                            x: originX + 250 * scale,
                            y: originY + 140 * scale
                        )
                        .allowsHitTesting(false)

                    clockButton(scale: scale)
                        .position(
                            x: originX + 250 * scale,
                            y: originY + 140 * scale
                        )

                    // Nest + Joey keep the shipped home geometry (not the Design AI nest).
                    NestPetView(pose: status.pose, daypart: daypart, onGreet: onGreetPet)
                        .frame(width: 288 * scale, height: 360 * scale)
                        .position(
                            x: originX + 340 * scale,
                            y: originY + 436 * scale
                        )

                    if status.situation.isInviteCardVisible(at: Date()) {
                        InvitationCardView(
                            onAccept: { onInviteAccept?() },
                            onSnooze: { onInviteSnooze?() },
                            onDoNotDisturb: { onInviteDoNotDisturb?() },
                            caretEdge: .leading,
                            scale: .nest
                        )
                        .position(
                            x: originX + 560 * scale,
                            y: originY + 400 * scale
                        )
                    }

                    clockLabel
                        .position(
                            x: originX + 250 * scale,
                            y: originY + 214 * scale
                        )

                    welcomeLabel(daypart: daypart)
                        .frame(width: 320, alignment: .trailing)
                        .position(
                            x: originX + sceneWidth - 40 * scale - 160,
                            y: originY + 342 * scale
                        )

                    plantLabel
                        .frame(width: 320, alignment: .leading)
                        .position(
                            x: originX + 40 * scale + 160,
                            y: originY + 342 * scale
                        )

                    reflectionButton(scale: scale)
                        .position(
                            x: originX + 760 * scale,
                            y: originY + 215 * scale
                        )

                    if status.isSessionActive, let startedAt = status.sessionStartedAt {
                        JoeyCompanionChipView(startedAt: startedAt)
                            .position(
                                x: originX + floorCenterX * scale,
                                y: originY + sceneHeight - 40 * scale - 71
                            )
                    }

                    JoeyPrimaryButton(
                        title: primaryTitle,
                        systemImage: primaryIcon,
                        action: primaryAction
                    )
                    .position(
                        x: originX + floorCenterX * scale,
                        y: originY + sceneHeight - 40 * scale - 25
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .background(theme.roomWall)
        }
    }

    private var primaryTitle: String {
        status.isSessionActive ? JoeyCopy.endCompanionship : JoeyCopy.startCompanionship
    }

    private var primaryIcon: String {
        status.isSessionActive ? "stop.fill" : "play.fill"
    }

    private func primaryAction() {
        onPrimaryAction()
    }

    private var clockLabel: some View {
        JoeyRoomLabel {
            if status.isSessionActive {
                Text(sessionReminderText)
            } else if status.situation.isDoNotDisturb {
                Text("勿扰中")
            } else {
                HStack(spacing: 0) {
                    Text("大约每 ")
                    Text("\(rhythmMinutes) 分钟")
                        .fontWeight(.semibold)
                        .foregroundStyle(chromeTheme.sageDeep)
                    Text("叫你一次")
                }
            }
        }
    }

    private var sessionReminderText: String {
        let situation = status.situation
        let now = Date()

        if situation.isDoNotDisturb {
            return "勿扰中"
        }
        if situation.isQuietActive {
            return "安静时段"
        }
        if situation.isSnoozeActive(at: now), let snoozeUntil = situation.snoozeUntil {
            return "\(Self.timeText(snoozeUntil)) 再问你一次"
        }

        switch situation.companion {
        case .invite:
            // Invitation card already carries the ask; clock stays a short status.
            return "该休息了"
        case .recover:
            return "休息中"
        case .complete:
            return "刚休息完"
        default:
            guard let due = situation.invitationDueDate() else {
                return "我就在这儿陪着。"
            }
            return "下次大约 \(Self.timeText(due)) 叫你"
        }
    }

    private static func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func welcomeLabel(daypart: RoomDaypart) -> some View {
        JoeyRoomLabel {
            Text(daypart.welcomeLine)
        }
    }

    private var plantLabel: some View {
        JoeyRoomLabel {
            if status.summary.todayBreaks > 0 {
                HStack(spacing: 0) {
                    Text("今天休息 ")
                    Text("\(status.summary.todayBreaks) 次")
                        .fontWeight(.semibold)
                        .foregroundStyle(chromeTheme.sageDeep)
                }
            } else {
                Text(JoeyCopy.emptyBreaks)
            }
        }
    }

    private func reflectionButton(scale: CGFloat) -> some View {
        Button(action: onOpenReflection) {
            Color.clear
                .frame(width: 120 * scale, height: 130 * scale)
                .overlay(alignment: .top) {
                    if isFrameHovering {
                        Text(JoeyCopy.reviewHint)
                            .font(JoeyType.caption)
                            .foregroundStyle(chromeTheme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(chromeTheme.popover)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(chromeTheme.hairline, lineWidth: 1)
                            )
                            .joeyShadowMD()
                            .offset(y: -34)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { isFrameHovering = $0 }
        .accessibilityLabel(Text(JoeyCopy.reviewHint))
    }

    private func clockButton(scale: CGFloat) -> some View {
        Button(action: onOpenClockSettings) {
            Color.clear
                .frame(width: 104 * scale, height: 104 * scale)
                .overlay(alignment: .top) {
                    if isClockHovering {
                        Text(JoeyCopy.clockHint)
                            .font(JoeyType.caption)
                            .foregroundStyle(chromeTheme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(chromeTheme.popover)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(chromeTheme.hairline, lineWidth: 1)
                            )
                            .joeyShadowMD()
                            .offset(y: -34)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { isClockHovering = $0 }
        .accessibilityLabel(Text(JoeyCopy.clockHint))
    }

}

// MARK: - Wall clock

/// Draws the clock hands from the real local time. Only this small canvas
/// refreshes each second; the room illustration stays static.
/// Second hand ticks once per second (discrete steps), like a wall quartz clock.
private struct RoomClockHandsView: View {
    let theme: JoeyTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Canvas { context, size in
                var canvas = context
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let unit = size.width / 88
                let components = Calendar.current.dateComponents(
                    [.hour, .minute, .second],
                    from: timeline.date
                )
                // Whole seconds only — no continuous sweep.
                let seconds = Double(components.second ?? 0)
                let minutes = Double(components.minute ?? 0) + seconds / 60
                let hours = Double((components.hour ?? 0) % 12) + minutes / 60

                drawHand(
                    in: &canvas,
                    center: center,
                    angle: hours / 12 * 2 * .pi,
                    length: 20 * unit,
                    tail: 4 * unit,
                    width: 4.2 * unit,
                    color: theme.roomHand
                )
                drawHand(
                    in: &canvas,
                    center: center,
                    angle: minutes / 60 * 2 * .pi,
                    length: 30 * unit,
                    tail: 5 * unit,
                    width: 3 * unit,
                    color: theme.roomHand
                )
                // Thin second hand with a short counterweight behind the hub.
                drawHand(
                    in: &canvas,
                    center: center,
                    angle: seconds / 60 * 2 * .pi,
                    length: 34 * unit,
                    tail: 9 * unit,
                    width: 1.15 * unit,
                    color: theme.apricotInk
                )
                // Hub: outer disc + small pin (reads as a real clock axle).
                canvas.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x - 3.6 * unit,
                        y: center.y - 3.6 * unit,
                        width: 7.2 * unit,
                        height: 7.2 * unit
                    )),
                    with: .color(theme.roomHand)
                )
                canvas.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x - 1.6 * unit,
                        y: center.y - 1.6 * unit,
                        width: 3.2 * unit,
                        height: 3.2 * unit
                    )),
                    with: .color(theme.apricotInk)
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func drawHand(
        in canvas: inout GraphicsContext,
        center: CGPoint,
        angle: Double,
        length: CGFloat,
        tail: CGFloat,
        width: CGFloat,
        color: Color
    ) {
        let tip = CGPoint(
            x: center.x + sin(angle) * length,
            y: center.y - cos(angle) * length
        )
        let heel = CGPoint(
            x: center.x - sin(angle) * tail,
            y: center.y + cos(angle) * tail
        )
        var hand = Path()
        hand.move(to: heel)
        hand.addLine(to: tip)
        canvas.stroke(
            hand,
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }
}

// MARK: - Room illustration

private struct RoomPainter {
    let theme: JoeyTheme
    /// Gentle curtain sway in design points; 0 when Reduce Motion is on.
    var curtainPhase: CGFloat = 0

    func draw(in context: inout GraphicsContext) {
        drawShell(&context)
        drawWindow(&context)
        drawClock(&context)
        drawPictureFrame(&context)
        drawPlant(&context)
        drawNest(&context)
        drawDesk(&context)
    }

    private func drawShell(_ context: inout GraphicsContext) {
        context.fill(
            Path(CGRect(x: -1000, y: -1000, width: 3000, height: 1532)),
            with: .color(theme.roomWall)
        )
        context.fill(
            Path(ellipseIn: CGRect(x: 520, y: -140, width: 760, height: 460)),
            with: .radialGradient(
                Gradient(colors: [theme.roomWash, theme.roomWash.opacity(0)]),
                center: CGPoint(x: 900, y: 90),
                startRadius: 10,
                endRadius: 380
            )
        )
        context.fill(
            Path(CGRect(x: -1000, y: 532, width: 3000, height: 2000)),
            with: .color(theme.roomFloor)
        )
        context.fill(
            Path(CGRect(x: -1000, y: 524, width: 3000, height: 8)),
            with: .color(theme.roomBase)
        )

        var lines = Path()
        lines.move(to: CGPoint(x: 0, y: 576))
        lines.addLine(to: CGPoint(x: 1080, y: 576))
        lines.move(to: CGPoint(x: 0, y: 620))
        lines.addLine(to: CGPoint(x: 1080, y: 620))
        lines.move(to: CGPoint(x: 220, y: 532))
        lines.addLine(to: CGPoint(x: 150, y: 680))
        lines.move(to: CGPoint(x: 620, y: 532))
        lines.addLine(to: CGPoint(x: 600, y: 680))
        lines.move(to: CGPoint(x: 900, y: 532))
        lines.addLine(to: CGPoint(x: 920, y: 680))
        context.stroke(
            lines,
            with: .color(theme.roomFloorLine.opacity(0.55)),
            lineWidth: 1
        )
    }

    private func drawWindow(_ context: inout GraphicsContext) {
        let windowRect = CGRect(x: 430, y: 96, width: 210, height: 204)

        context.fill(
            Path(roundedRect: windowRect, cornerRadius: 8),
            with: .color(theme.roomSky)
        )

        var inner = context
        inner.clip(to: Path(roundedRect: windowRect.insetBy(dx: 4, dy: 4), cornerRadius: 6))

        // Outdoor disc (sun by day, moon at night) — no beams.
        let discCenter = CGPoint(x: 575, y: 148)
        let discRadius: CGFloat = theme.roomShowsStars ? 14 : 18
        inner.fill(
            Path(ellipseIn: CGRect(
                x: discCenter.x - discRadius,
                y: discCenter.y - discRadius,
                width: discRadius * 2,
                height: discRadius * 2
            )),
            with: .color(theme.roomOutdoorDisc.opacity(theme.roomShowsStars ? 0.92 : 0.85))
        )
        if theme.roomShowsStars {
            for point in [
                CGPoint(x: 460, y: 128),
                CGPoint(x: 505, y: 118),
                CGPoint(x: 548, y: 136),
                CGPoint(x: 600, y: 122),
                CGPoint(x: 620, y: 150)
            ] {
                inner.fill(
                    Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 2.2, height: 2.2)),
                    with: .color(Color.white.opacity(0.55))
                )
            }
        }

        var hill1 = Path()
        hill1.move(to: CGPoint(x: 430, y: 200))
        hill1.addCurve(
            to: CGPoint(x: 560, y: 190),
            control1: CGPoint(x: 480, y: 182),
            control2: CGPoint(x: 520, y: 210)
        )
        hill1.addCurve(
            to: CGPoint(x: 640, y: 180),
            control1: CGPoint(x: 600, y: 172),
            control2: CGPoint(x: 630, y: 186)
        )
        hill1.addLine(to: CGPoint(x: 640, y: 300))
        hill1.addLine(to: CGPoint(x: 430, y: 300))
        hill1.closeSubpath()
        inner.fill(hill1, with: .color(theme.roomHill1))

        var hill2 = Path()
        hill2.move(to: CGPoint(x: 430, y: 226))
        hill2.addCurve(
            to: CGPoint(x: 566, y: 218),
            control1: CGPoint(x: 480, y: 208),
            control2: CGPoint(x: 525, y: 236)
        )
        hill2.addCurve(
            to: CGPoint(x: 640, y: 210),
            control1: CGPoint(x: 606, y: 202),
            control2: CGPoint(x: 630, y: 214)
        )
        hill2.addLine(to: CGPoint(x: 640, y: 300))
        hill2.addLine(to: CGPoint(x: 430, y: 300))
        hill2.closeSubpath()
        inner.fill(hill2, with: .color(theme.roomHill2))

        context.stroke(
            Path(roundedRect: windowRect, cornerRadius: 8),
            with: .color(theme.roomFrame),
            lineWidth: 9
        )

        var mullions = Path()
        mullions.move(to: CGPoint(x: 535, y: 96))
        mullions.addLine(to: CGPoint(x: 535, y: 300))
        mullions.move(to: CGPoint(x: 430, y: 198))
        mullions.addLine(to: CGPoint(x: 640, y: 198))
        context.stroke(mullions, with: .color(theme.roomFrame), lineWidth: 7)

        context.fill(
            Path(roundedRect: CGRect(x: 414, y: 294, width: 242, height: 10), cornerRadius: 5),
            with: .color(theme.roomSill)
        )

        let sway = curtainPhase
        var leftCurtain = Path()
        leftCurtain.move(to: CGPoint(x: 418, y: 90))
        leftCurtain.addCurve(
            to: CGPoint(x: 414 + sway, y: 294),
            control1: CGPoint(x: 400 + sway * 0.4, y: 130),
            control2: CGPoint(x: 404 + sway * 0.8, y: 200)
        )
        leftCurtain.addLine(to: CGPoint(x: 434 + sway * 0.35, y: 294))
        leftCurtain.addCurve(
            to: CGPoint(x: 438, y: 90),
            control1: CGPoint(x: 424 + sway * 0.5, y: 200),
            control2: CGPoint(x: 424, y: 130)
        )
        leftCurtain.closeSubpath()
        context.fill(leftCurtain, with: .color(theme.roomCurtain.opacity(0.92)))

        var rightCurtain = Path()
        rightCurtain.move(to: CGPoint(x: 652, y: 90))
        rightCurtain.addCurve(
            to: CGPoint(x: 656 - sway, y: 294),
            control1: CGPoint(x: 670 - sway * 0.4, y: 130),
            control2: CGPoint(x: 666 - sway * 0.8, y: 200)
        )
        rightCurtain.addLine(to: CGPoint(x: 636 - sway * 0.35, y: 294))
        rightCurtain.addCurve(
            to: CGPoint(x: 632, y: 90),
            control1: CGPoint(x: 646 - sway * 0.5, y: 200),
            control2: CGPoint(x: 646, y: 130)
        )
        rightCurtain.closeSubpath()
        context.fill(rightCurtain, with: .color(theme.roomCurtain.opacity(0.92)))
    }

    private func drawClock(_ context: inout GraphicsContext) {
        let center = CGPoint(x: 250, y: 140)
        let circle = Path(
            ellipseIn: CGRect(x: center.x - 44, y: center.y - 44, width: 88, height: 88)
        )
        context.fill(circle, with: .color(theme.roomClock))
        context.stroke(circle, with: .color(theme.roomClockRim), lineWidth: 5)

        // 60 faint minute marks + 12 stronger hour marks (wall-clock read).
        var minuteTicks = Path()
        var hourTicks = Path()
        for index in 0..<60 {
            let angle = Double(index) * .pi / 30 - .pi / 2
            let isHour = index % 5 == 0
            let outerR: CGFloat = 38
            let innerR: CGFloat = isHour ? 30 : 35
            let outer = CGPoint(
                x: center.x + cos(angle) * outerR,
                y: center.y + sin(angle) * outerR
            )
            let inner = CGPoint(
                x: center.x + cos(angle) * innerR,
                y: center.y + sin(angle) * innerR
            )
            if isHour {
                hourTicks.move(to: outer)
                hourTicks.addLine(to: inner)
            } else {
                minuteTicks.move(to: outer)
                minuteTicks.addLine(to: inner)
            }
        }
        context.stroke(
            minuteTicks,
            with: .color(theme.roomClockTick.opacity(0.45)),
            style: StrokeStyle(lineWidth: 1, lineCap: .round)
        )
        context.stroke(
            hourTicks,
            with: .color(theme.roomClockTick),
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
        )
        // The hands are drawn by `RoomClockHandsView` so they can follow the
        // real time without repainting the whole room.
    }

    private func drawPictureFrame(_ context: inout GraphicsContext) {
        var string = Path()
        string.move(to: CGPoint(x: 760, y: 142))
        string.addLine(to: CGPoint(x: 760, y: 158))
        context.stroke(string, with: .color(theme.roomClockRim), lineWidth: 3)

        let frame = CGRect(x: 700, y: 158, width: 120, height: 122)
        context.fill(
            Path(roundedRect: frame, cornerRadius: 6),
            with: .color(theme.roomPaper)
        )
        context.stroke(
            Path(roundedRect: frame, cornerRadius: 6),
            with: .color(theme.roomFrame),
            lineWidth: 6
        )

        var dashed = Path()
        dashed.move(to: CGPoint(x: 718, y: 246))
        dashed.addCurve(
            to: CGPoint(x: 802, y: 228),
            control1: CGPoint(x: 744, y: 230),
            control2: CGPoint(x: 778, y: 238)
        )
        context.stroke(
            dashed,
            with: .color(theme.roomNoteLine.opacity(0.5)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 7])
        )

        var stems = Path()
        stems.move(to: CGPoint(x: 724, y: 234))
        stems.addCurve(
            to: CGPoint(x: 727, y: 212),
            control1: CGPoint(x: 724, y: 226),
            control2: CGPoint(x: 726, y: 218)
        )
        stems.move(to: CGPoint(x: 748, y: 230))
        stems.addCurve(
            to: CGPoint(x: 751, y: 208),
            control1: CGPoint(x: 748, y: 222),
            control2: CGPoint(x: 750, y: 214)
        )
        stems.move(to: CGPoint(x: 772, y: 234))
        stems.addCurve(
            to: CGPoint(x: 775, y: 212),
            control1: CGPoint(x: 772, y: 226),
            control2: CGPoint(x: 774, y: 218)
        )
        stems.move(to: CGPoint(x: 796, y: 226))
        stems.addCurve(
            to: CGPoint(x: 799, y: 204),
            control1: CGPoint(x: 796, y: 218),
            control2: CGPoint(x: 798, y: 210)
        )
        context.stroke(
            stems,
            with: .color(theme.roomStem),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
        )

        fillEllipse(&context, center: CGPoint(x: 730, y: 210), rx: 5, ry: 9, rotation: -20, color: theme.roomLeaf)
        fillEllipse(&context, center: CGPoint(x: 754, y: 206), rx: 5, ry: 9, rotation: 20, color: theme.roomLeaf)
        fillEllipse(&context, center: CGPoint(x: 778, y: 210), rx: 5, ry: 9, rotation: -20, color: theme.roomLeaf)
        fillEllipse(&context, center: CGPoint(x: 802, y: 202), rx: 5, ry: 9, rotation: 20, color: theme.roomLeaf)

        context.draw(
            Text("回顾")
                .font(.system(size: 13))
                .foregroundStyle(theme.roomNoteLine),
            at: CGPoint(x: 760, y: 264),
            anchor: .center
        )
    }

    private func drawPlant(_ context: inout GraphicsContext) {
        fillEllipse(
            &context,
            center: CGPoint(x: 120, y: 556),
            rx: 40,
            ry: 8,
            color: Color(hex: 0x3F3A35),
            opacity: 0.06
        )

        var pot = Path()
        pot.move(to: CGPoint(x: 98, y: 556))
        pot.addLine(to: CGPoint(x: 104, y: 500))
        pot.addLine(to: CGPoint(x: 136, y: 500))
        pot.addLine(to: CGPoint(x: 142, y: 556))
        pot.closeSubpath()
        context.fill(pot, with: .color(theme.roomPot))

        var stems = Path()
        stems.move(to: CGPoint(x: 120, y: 500))
        stems.addCurve(
            to: CGPoint(x: 122, y: 378),
            control1: CGPoint(x: 120, y: 450),
            control2: CGPoint(x: 126, y: 414)
        )
        stems.move(to: CGPoint(x: 120, y: 480))
        stems.addCurve(
            to: CGPoint(x: 98, y: 430),
            control1: CGPoint(x: 104, y: 466),
            control2: CGPoint(x: 96, y: 448)
        )
        stems.move(to: CGPoint(x: 120, y: 460))
        stems.addCurve(
            to: CGPoint(x: 144, y: 410),
            control1: CGPoint(x: 138, y: 446),
            control2: CGPoint(x: 146, y: 428)
        )
        context.stroke(
            stems,
            with: .color(theme.roomStem),
            style: StrokeStyle(lineWidth: 4, lineCap: .round)
        )

        fillEllipse(&context, center: CGPoint(x: 114, y: 392), rx: 16, ry: 28, rotation: -18, color: theme.roomLeaf)
        fillEllipse(&context, center: CGPoint(x: 130, y: 366), rx: 14, ry: 26, rotation: 22, color: theme.roomLeaf)
        fillEllipse(&context, center: CGPoint(x: 96, y: 426), rx: 13, ry: 22, rotation: -40, color: theme.roomLeaf)
        fillEllipse(&context, center: CGPoint(x: 146, y: 406), rx: 12, ry: 21, rotation: 40, color: theme.roomLeaf)
        fillEllipse(&context, center: CGPoint(x: 122, y: 440), rx: 14, ry: 24, rotation: 4, color: theme.roomLeaf, opacity: 0.85)
    }

    private func drawNest(_ context: inout GraphicsContext) {
        fillEllipse(
            &context,
            center: CGPoint(x: 340, y: 612),
            rx: 230,
            ry: 42,
            color: theme.roomRug,
            opacity: 0.5
        )
        fillEllipse(&context, center: CGPoint(x: 340, y: 598), rx: 186, ry: 38, color: theme.roomNestDark)

        var nest = Path()
        nest.move(to: CGPoint(x: 154, y: 598))
        nest.addCurve(
            to: CGPoint(x: 340, y: 548),
            control1: CGPoint(x: 154, y: 568),
            control2: CGPoint(x: 238, y: 548)
        )
        nest.addCurve(
            to: CGPoint(x: 526, y: 598),
            control1: CGPoint(x: 442, y: 548),
            control2: CGPoint(x: 526, y: 568)
        )
        nest.addCurve(
            to: CGPoint(x: 340, y: 648),
            control1: CGPoint(x: 526, y: 630),
            control2: CGPoint(x: 442, y: 648)
        )
        nest.addCurve(
            to: CGPoint(x: 154, y: 598),
            control1: CGPoint(x: 238, y: 648),
            control2: CGPoint(x: 154, y: 630)
        )
        nest.closeSubpath()
        context.fill(nest, with: .color(theme.roomNest))
        context.stroke(nest, with: .color(theme.roomNestRim.opacity(0.85)), lineWidth: 2.5)

        fillEllipse(&context, center: CGPoint(x: 340, y: 586), rx: 154, ry: 42, color: theme.roomCushion)
        fillEllipse(&context, center: CGPoint(x: 340, y: 580), rx: 140, ry: 34, color: theme.roomCushion2)

        var lip = Path()
        lip.move(to: CGPoint(x: 194, y: 602))
        lip.addCurve(
            to: CGPoint(x: 486, y: 602),
            control1: CGPoint(x: 228, y: 628),
            control2: CGPoint(x: 452, y: 628)
        )
        lip.addCurve(
            to: CGPoint(x: 340, y: 646),
            control1: CGPoint(x: 476, y: 632),
            control2: CGPoint(x: 412, y: 646)
        )
        lip.addCurve(
            to: CGPoint(x: 194, y: 602),
            control1: CGPoint(x: 268, y: 646),
            control2: CGPoint(x: 204, y: 632)
        )
        lip.closeSubpath()
        context.fill(lip, with: .color(theme.roomNest))
    }

    private func drawDesk(_ context: inout GraphicsContext) {
        context.fill(
            Path(roundedRect: CGRect(x: 730, y: 500, width: 290, height: 14), cornerRadius: 4),
            with: .color(theme.roomDesk)
        )
        context.fill(
            Path(CGRect(x: 748, y: 514, width: 10, height: 146)),
            with: .color(theme.roomDeskLeg)
        )
        context.fill(
            Path(CGRect(x: 1002, y: 514, width: 10, height: 146)),
            with: .color(theme.roomDeskLeg)
        )

        context.drawLayer { layer in
            layer.translateBy(x: 852, y: 482)
            layer.rotate(by: .degrees(-4))
            layer.fill(
                Path(roundedRect: CGRect(x: -58, y: -18, width: 116, height: 40), cornerRadius: 4),
                with: .color(theme.roomPaper)
            )
            layer.stroke(
                Path(roundedRect: CGRect(x: -58, y: -18, width: 116, height: 40), cornerRadius: 4),
                with: .color(theme.roomPaperLine),
                lineWidth: 1
            )
            var noteLines = Path()
            noteLines.move(to: CGPoint(x: -44, y: -6))
            noteLines.addLine(to: CGPoint(x: 38, y: -6))
            noteLines.move(to: CGPoint(x: -44, y: 4))
            noteLines.addLine(to: CGPoint(x: 26, y: 4))
            layer.stroke(
                noteLines,
                with: .color(theme.roomNoteLine.opacity(0.3)),
                lineWidth: 1.6
            )
        }

        context.fill(
            Path(roundedRect: CGRect(x: 928, y: 462, width: 44, height: 40), cornerRadius: 7),
            with: .color(theme.roomMug)
        )
        var handle = Path()
        handle.move(to: CGPoint(x: 972, y: 470))
        handle.addCurve(
            to: CGPoint(x: 972, y: 492),
            control1: CGPoint(x: 986, y: 470),
            control2: CGPoint(x: 986, y: 492)
        )
        context.stroke(
            handle,
            with: .color(theme.roomMug),
            style: StrokeStyle(lineWidth: 5, lineCap: .round)
        )
        fillEllipse(
            &context,
            center: CGPoint(x: 950, y: 462),
            rx: 22,
            ry: 5,
            color: theme.roomMugTop,
            opacity: 0.5
        )

        let potOrigin = CGPoint(x: 886, y: 422)
        context.fill(
            Path(roundedRect: CGRect(x: potOrigin.x - 14, y: potOrigin.y + 54, width: 28, height: 26), cornerRadius: 4),
            with: .color(theme.roomPot)
        )
        var potStems = Path()
        potStems.move(to: CGPoint(x: potOrigin.x, y: potOrigin.y + 54))
        potStems.addCurve(
            to: CGPoint(x: potOrigin.x - 12, y: potOrigin.y + 24),
            control1: CGPoint(x: potOrigin.x, y: potOrigin.y + 40),
            control2: CGPoint(x: potOrigin.x - 6, y: potOrigin.y + 30)
        )
        potStems.move(to: CGPoint(x: potOrigin.x, y: potOrigin.y + 54))
        potStems.addCurve(
            to: CGPoint(x: potOrigin.x + 16, y: potOrigin.y + 26),
            control1: CGPoint(x: potOrigin.x + 4, y: potOrigin.y + 38),
            control2: CGPoint(x: potOrigin.x + 12, y: potOrigin.y + 30)
        )
        context.stroke(
            potStems,
            with: .color(theme.roomStem),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
        )
        fillEllipse(&context, center: CGPoint(x: potOrigin.x - 14, y: potOrigin.y + 22), rx: 9, ry: 13, rotation: -30, color: theme.roomLeaf)
        fillEllipse(&context, center: CGPoint(x: potOrigin.x + 18, y: potOrigin.y + 24), rx: 8, ry: 12, rotation: 30, color: theme.roomLeaf)
        fillEllipse(&context, center: CGPoint(x: potOrigin.x + 2, y: potOrigin.y + 14), rx: 8, ry: 12, color: theme.roomLeaf, opacity: 0.9)
    }

    func drawJoey(
        _ context: inout GraphicsContext,
        isHappy: Bool,
        isAwake: Bool,
        isEarTwitching: Bool
    ) {
        context.drawLayer { layer in
            layer.fill(
                Path(ellipseIn: CGRect(x: 66, y: 340, width: 188, height: 24)),
                with: .color(Color(hex: 0x3F3A35, opacity: 0.08))
            )

            var tail = Path()
            tail.move(to: CGPoint(x: 228, y: 314))
            tail.addCurve(
                to: CGPoint(x: 290, y: 272),
                control1: CGPoint(x: 268, y: 324),
                control2: CGPoint(x: 294, y: 300)
            )
            tail.addCurve(
                to: CGPoint(x: 256, y: 256),
                control1: CGPoint(x: 287, y: 250),
                control2: CGPoint(x: 266, y: 244)
            )
            tail.addCurve(
                to: CGPoint(x: 269, y: 277),
                control1: CGPoint(x: 248, y: 266),
                control2: CGPoint(x: 256, y: 280)
            )
            layer.stroke(
                tail,
                with: .color(theme.joeyTail),
                style: StrokeStyle(lineWidth: 23, lineCap: .round)
            )

            let restingTilt: Double = (isAwake || isHappy) ? 0 : 5
            drawEar(
                &layer,
                mirrored: false,
                twitch: -restingTilt + (isEarTwitching ? -3 : 0)
            )
            drawEar(
                &layer,
                mirrored: true,
                twitch: restingTilt + (isEarTwitching ? 3 : 0)
            )
            drawJoeyBody(&layer)

            fillEllipse(&layer, center: CGPoint(x: 128, y: 337), rx: 27, ry: 13, color: theme.joeyPaw)
            fillEllipse(&layer, center: CGPoint(x: 192, y: 337), rx: 27, ry: 13, color: theme.joeyPaw)

            var scarf = Path()
            scarf.move(to: CGPoint(x: 122, y: 244))
            scarf.addCurve(
                to: CGPoint(x: 198, y: 244),
                control1: CGPoint(x: 142, y: 258),
                control2: CGPoint(x: 178, y: 258)
            )
            layer.stroke(
                scarf,
                with: .color(theme.joeyScarf),
                style: StrokeStyle(lineWidth: 9, lineCap: .round)
            )
            layer.fill(
                Path(ellipseIn: CGRect(x: 193, y: 240, width: 14, height: 14)),
                with: .color(theme.joeyScarf)
            )

            fillEllipse(&layer, center: CGPoint(x: 84, y: 262), rx: 18, ry: 28, rotation: 10, color: theme.joeyArm)
            fillEllipse(&layer, center: CGPoint(x: 236, y: 262), rx: 18, ry: 28, rotation: -10, color: theme.joeyArm)

            drawJoeyFace(&layer, isHappy: isHappy, isAwake: isAwake)
        }
    }

    private func drawEar(
        _ context: inout GraphicsContext,
        mirrored: Bool,
        twitch: Double
    ) {
        let mirror = CGAffineTransform.identity
            .translatedBy(x: mirrored ? 320 : 0, y: 0)
            .scaledBy(x: mirrored ? -1 : 1, y: 1)
        let baseX: CGFloat = mirrored ? 202 : 118
        let rotation = CGAffineTransform(translationX: baseX, y: 148)
            .rotated(by: .pi * twitch / 180)
            .translatedBy(x: -baseX, y: -148)
        let transform = mirror.concatenating(rotation)

        var outer = Path()
        outer.move(to: CGPoint(x: 118, y: 148))
        outer.addCurve(
            to: CGPoint(x: 93, y: 68),
            control1: CGPoint(x: 100, y: 126),
            control2: CGPoint(x: 88, y: 90)
        )
        outer.addCurve(
            to: CGPoint(x: 126, y: 62),
            control1: CGPoint(x: 97, y: 50),
            control2: CGPoint(x: 116, y: 46)
        )
        outer.addCurve(
            to: CGPoint(x: 146, y: 140),
            control1: CGPoint(x: 138, y: 80),
            control2: CGPoint(x: 144, y: 116)
        )
        outer.closeSubpath()
        context.fill(outer.applying(transform), with: .color(theme.joeyBody))

        var inner = Path()
        inner.move(to: CGPoint(x: 120, y: 136))
        inner.addCurve(
            to: CGPoint(x: 105, y: 80),
            control1: CGPoint(x: 108, y: 118),
            control2: CGPoint(x: 101, y: 94)
        )
        inner.addCurve(
            to: CGPoint(x: 122, y: 78),
            control1: CGPoint(x: 108, y: 70),
            control2: CGPoint(x: 117, y: 69)
        )
        inner.addCurve(
            to: CGPoint(x: 136, y: 132),
            control1: CGPoint(x: 129, y: 90),
            control2: CGPoint(x: 134, y: 114)
        )
        inner.closeSubpath()
        context.fill(inner.applying(transform), with: .color(theme.joeyInnerEar))
    }

    private func drawJoeyBody(_ context: inout GraphicsContext) {
        var body = Path()
        body.move(to: CGPoint(x: 160, y: 116))
        body.addCurve(
            to: CGPoint(x: 242, y: 231),
            control1: CGPoint(x: 209, y: 116),
            control2: CGPoint(x: 242, y: 167)
        )
        body.addCurve(
            to: CGPoint(x: 160, y: 342),
            control1: CGPoint(x: 242, y: 299),
            control2: CGPoint(x: 208, y: 342)
        )
        body.addCurve(
            to: CGPoint(x: 78, y: 231),
            control1: CGPoint(x: 112, y: 342),
            control2: CGPoint(x: 78, y: 299)
        )
        body.addCurve(
            to: CGPoint(x: 160, y: 116),
            control1: CGPoint(x: 78, y: 167),
            control2: CGPoint(x: 111, y: 116)
        )
        body.closeSubpath()
        context.fill(body, with: .color(theme.joeyBody))

        var shade = Path()
        shade.move(to: CGPoint(x: 160, y: 342))
        shade.addCurve(
            to: CGPoint(x: 78, y: 231),
            control1: CGPoint(x: 112, y: 342),
            control2: CGPoint(x: 78, y: 299)
        )
        shade.addCurve(
            to: CGPoint(x: 79, y: 212),
            control1: CGPoint(x: 78, y: 224),
            control2: CGPoint(x: 78, y: 218)
        )
        shade.addCurve(
            to: CGPoint(x: 160, y: 322),
            control1: CGPoint(x: 93, y: 298),
            control2: CGPoint(x: 118, y: 322)
        )
        shade.addCurve(
            to: CGPoint(x: 241, y: 212),
            control1: CGPoint(x: 202, y: 322),
            control2: CGPoint(x: 227, y: 298)
        )
        shade.addCurve(
            to: CGPoint(x: 242, y: 231),
            control1: CGPoint(x: 242, y: 218),
            control2: CGPoint(x: 242, y: 224)
        )
        shade.addCurve(
            to: CGPoint(x: 160, y: 342),
            control1: CGPoint(x: 242, y: 299),
            control2: CGPoint(x: 208, y: 342)
        )
        shade.closeSubpath()
        context.fill(shade, with: .color(theme.joeyShade.opacity(0.5)))
    }

    private func drawJoeyFace(
        _ context: inout GraphicsContext,
        isHappy: Bool,
        isAwake: Bool
    ) {
        guard !isHappy else {
            fillEllipse(&context, center: CGPoint(x: 111, y: 228), rx: 18, ry: 9, color: theme.joeyBlush, opacity: 0.36)
            fillEllipse(&context, center: CGPoint(x: 209, y: 228), rx: 18, ry: 9, color: theme.joeyBlush, opacity: 0.36)

            var eyes = Path()
            eyes.move(to: CGPoint(x: 124, y: 207))
            eyes.addCurve(
                to: CGPoint(x: 147, y: 207),
                control1: CGPoint(x: 130, y: 198),
                control2: CGPoint(x: 141, y: 198)
            )
            eyes.move(to: CGPoint(x: 173, y: 207))
            eyes.addCurve(
                to: CGPoint(x: 196, y: 207),
                control1: CGPoint(x: 179, y: 198),
                control2: CGPoint(x: 190, y: 198)
            )
            context.stroke(
                eyes,
                with: .color(theme.joeyEye),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )

            var nose = Path()
            nose.move(to: CGPoint(x: 160, y: 214))
            nose.addCurve(
                to: CGPoint(x: 166, y: 220),
                control1: CGPoint(x: 165, y: 214),
                control2: CGPoint(x: 168, y: 217)
            )
            nose.addCurve(
                to: CGPoint(x: 154, y: 220),
                control1: CGPoint(x: 164, y: 222.5),
                control2: CGPoint(x: 156, y: 222.5)
            )
            nose.addCurve(
                to: CGPoint(x: 160, y: 214),
                control1: CGPoint(x: 152, y: 217),
                control2: CGPoint(x: 155, y: 214)
            )
            nose.closeSubpath()
            context.fill(nose, with: .color(theme.joeyNose))

            var mouth = Path()
            mouth.move(to: CGPoint(x: 150, y: 226))
            mouth.addCurve(
                to: CGPoint(x: 170, y: 226),
                control1: CGPoint(x: 152, y: 238),
                control2: CGPoint(x: 168, y: 238)
            )
            mouth.closeSubpath()
            context.fill(mouth, with: .color(theme.joeyMouth))
            return
        }

        fillEllipse(&context, center: CGPoint(x: 111, y: 226), rx: 18, ry: 9, color: theme.joeyBlush, opacity: isAwake ? 0.26 : 0.2)
        fillEllipse(&context, center: CGPoint(x: 209, y: 226), rx: 18, ry: 9, color: theme.joeyBlush, opacity: isAwake ? 0.26 : 0.2)

        if isAwake {
            fillEllipse(&context, center: CGPoint(x: 134, y: 204), rx: 8.5, ry: 11, color: theme.joeyEye)
            fillEllipse(&context, center: CGPoint(x: 186, y: 204), rx: 8.5, ry: 11, color: theme.joeyEye)
            fillEllipse(&context, center: CGPoint(x: 131, y: 200), rx: 2.8, ry: 2.8, color: .white)
            fillEllipse(&context, center: CGPoint(x: 183, y: 200), rx: 2.8, ry: 2.8, color: .white)
        } else {
            var eyes = Path()
            eyes.move(to: CGPoint(x: 124, y: 205))
            eyes.addQuadCurve(
                to: CGPoint(x: 144, y: 205),
                control: CGPoint(x: 134, y: 212)
            )
            eyes.move(to: CGPoint(x: 176, y: 205))
            eyes.addQuadCurve(
                to: CGPoint(x: 196, y: 205),
                control: CGPoint(x: 186, y: 212)
            )
            context.stroke(
                eyes,
                with: .color(theme.joeyEye),
                style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
            )
        }

        var nose = Path()
        nose.move(to: CGPoint(x: 160, y: 216))
        nose.addCurve(
            to: CGPoint(x: 166.5, y: 223),
            control1: CGPoint(x: 166, y: 216),
            control2: CGPoint(x: 169, y: 220)
        )
        nose.addCurve(
            to: CGPoint(x: 153.5, y: 223),
            control1: CGPoint(x: 164.5, y: 225.5),
            control2: CGPoint(x: 155.5, y: 225.5)
        )
        nose.addCurve(
            to: CGPoint(x: 160, y: 216),
            control1: CGPoint(x: 151, y: 220),
            control2: CGPoint(x: 154, y: 216)
        )
        nose.closeSubpath()
        context.fill(nose, with: .color(theme.joeyNose))

        var mouth = Path()
        mouth.move(to: CGPoint(x: 160, y: 224))
        mouth.addCurve(
            to: CGPoint(x: 150, y: 228),
            control1: CGPoint(x: 158, y: 230),
            control2: CGPoint(x: 153, y: 232)
        )
        mouth.move(to: CGPoint(x: 160, y: 224))
        mouth.addCurve(
            to: CGPoint(x: 170, y: 228),
            control1: CGPoint(x: 162, y: 230),
            control2: CGPoint(x: 167, y: 232)
        )
        context.stroke(
            mouth,
            with: .color(theme.joeyMouth),
            style: StrokeStyle(lineWidth: 2.3, lineCap: .round)
        )
    }

    private func fillEllipse(
        _ context: inout GraphicsContext,
        center: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        rotation: Double = 0,
        color: Color,
        opacity: Double = 1
    ) {
        context.drawLayer { layer in
            layer.translateBy(x: center.x, y: center.y)
            layer.rotate(by: .degrees(rotation))
            layer.fill(
                Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)),
                with: .color(color.opacity(opacity))
            )
        }
    }
}
